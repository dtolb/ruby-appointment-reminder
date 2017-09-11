require "bundler"
Bundler.require

require "rack/moneta_store"
require "sinatra/json"
require "sinatra/cookies"

require "./database_backend"
require "./host_backend"
require "./helper"

class AppointmentReminderApp < Sinatra::Base
  helpers Sinatra::Cookies
  use Rack::PostBodyContentTypeParser
  use Rack::MonetaStore, :File, :dir => File.join(Dir.tmpdir(), ".cache")
  use DatabaseBackend
  use HostBackend

  set :public_dir, File.join(File.dirname(__FILE__), "public")
  set :show_exceptions, false

  before "/*" do
    env["user"] = get_user_by_number(env, cookies["user_phone_number"])
  end

  error do
    e = env["sinatra.error"]
    json({error: e.message.strip()})
  end

  get "/" do
    redirect "/index.html"
  end

  post "/register" do
    user = get_user_by_number(env, params["phoneNumber"])
    raise "User with this number is registered already" if user
    db = env["database"]
    params["_id"] = BSON::ObjectId.new()
    params.delete("inProgress")
    db["User"].insert_one(params)
    send_verification_code(env, params["phoneNumber"])
    ""
  end

  post "/login" do
    user = get_user_by_number(env, params["phoneNumber"])
    raise "User with this number is not registered yet" unless user
    send_verification_code(env, user["phoneNumber"])
    ""
  end

  post "/logout" do
    cookies["user_phone_number"] = nil
  end

  post "/verify-code" do
    user = get_user_by_number(env, params["phoneNumber"])
    raise "User with this number is not registered yet" unless user
    raise "Invalid verification code" if !params["code"] || user["verificationCode"] != params["code"]
    user.delete("verificationCode")
    db = env["database"]
    db["User"].update_one({_id: user["_id"]}, {"$set" => {verificationCode: nil}})
    cookies["user_phone_number"] = user["phoneNumber"]
    user["id"] = user["_id"].to_s()
    user.delete("_id")
    json user
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
      puts exception
    end
    ""
  end

  before "/reminder*" do
    halt 401 unless env["user"]
  end

  get "/reminder" do
    db = env["database"]
    user = env["user"]
    reminders = db["Reminder"].find({user: user["_id"]}, {sort: {"createdAt" => -1}})
    reminders = reminders.to_a.map do |i|
      i["id"] = i["_id"].to_s()
      i.delete("_id")
      i
    end
    json reminders
  end

  post "/reminder" do
    db = env["database"]
    user = env["user"]
    params["time"] = prepare_time(params["time"])
    params["user"] = user["_id"]
    params["enabled"] = true
    params["completed"] = false
    params["createdAt"] = DateTime.now()
    params["_id"] = BSON::ObjectId.new()
    params.delete("inProgress")
    db["Reminder"].insert_one(params)
    params["id"] = params["_id"].to_s()
    params.delete("_id")
    params["user"] = params["user"].to_s()
    json params
  end

  post "/reminder/:id/enabled" do
    db = env["database"]
    user = env["user"]
    db["Reminder"].update_one({_id: BSON::ObjectId.from_string(params["id"]), user: user["_id"]}, {"$set" => {enabled: params["enabled"] == "true"}})
    ""
  end

  delete "/reminder/:id" do
    db = env["database"]
    user = env["user"]
    db["Reminder"].delete_one({_id: BSON::ObjectId.from_string(params["id"]), user: user["_id"]})
    ""
  end

end
