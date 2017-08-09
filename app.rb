require "bundler"
Bundler.require

require "rack/moneta_store"

require "./phone_number_backend"
require "./database_backend"
require "./host_backend"
require "./helper"

class AppointmentReminderApp < Sinatra::Base
  enable :sessions
  use Rack::PostBodyContentTypeParser
  use Rack::MonetaStore, :File, :dir => File.join(Dir.tmpdir(), ".cache")
  use DatabaseBackend
  use PhoneNumberBackend
  use HostBackend

  set :public_dir, File.join(File.dirname(__FILE__), "public")

  get "/" do
    redirect "/index.html"
  end

  post "/register" do
    user = get_user_by_number(env, params["phoneNumber"])
    raise "User with this number is registered already" if user
    db = env["database"]
    params["_id"] = BSON::ObjectId.new(),
    db["User"].insert_one(params)
    send_verification_code(env, params["phoneNumber"])
    ""
  end

  post "/login" do
    user = get_user_by_number(env, params["phoneNumber"])
    raise "User with this number is not registered yet" unless user
    send_verification_code(user["phoneNumber"])
    ""
  end

  post "/verify-code" do
    user = get_user_by_number(env, params["phoneNumber"])
    raise "User with this number is not registered yet" unless user
    raise "Invalid verification code" if !params["code"] || user["verificationCode"] != params["code"]
    user.delete("verificationCode")
    db = env["database"]
    db["User"].update({_id: user["_id"]}, {"$set" => {verificationCode: nil}})
    session[:user_phone_number] = user["phoneNumber"]
    user["id"] = user["_id"].to_s()
    json user
  end

  post "/logout" do
    session.delete(:user_phone_number)
    ""
  end

  post "/bandwidth/call-callback" do
    api = get_bandwidth_api()
    call = Bandwidth::Call.new({id: params["callId"]}, api)
    begin
      case params["eventType"]
        when "answer" then call.speak_sentence(params["tag"])
        when "speak" then call.hangup() if params["status"] == "done"
      end
    rescue => exception
      put exception
    end
    ""
  end

  before "/reminder*" do
    halt 401 unless env[:user]
  end

  get "/reminder" do
    db = env["database"]
    user = env["user"]
    reminders = db["Reminder"].find({user: user["_id"]}, {sort: {"createdAt" => -1}})
    reminders.to_a.map do |i|
      i["id"] = i["_id"].to_s()
    end
  end

  post "/reminder" do
    db = env["database"]
    user = env["user"]
    params["time"] = prepare_time(params["time"])
    params["user"] = user["_id"]
    params["createdAt"] = Time.now()
    db["Reminder"].insert_one(params)
    params["id"] = params["_id"].to_s()
    params
  end

  post "/reminder/:id/enabled" do
    db = env["database"]
    user = env["user"]
    db["Reminder"].update({_id: params["id"], user: user["_id"]}, {"$set" => {enabled: params["enabled"] == "true"}})
    ""
  end

  delete "/reminder/:id" do
    db = env["database"]
    user = env["user"]
    db["Reminder"].remove({_id: params["id"], user: user["_id"]})
    ""
  end

end
