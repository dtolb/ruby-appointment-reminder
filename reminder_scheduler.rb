require "bundler"
Bundler.require
require "moneta"
require "date"
require "./helper"

def add_days(time, days)
  time.to_datetime.next_day(days)
end

def add_months(time, months)
  time.to_datetime.next_month(months)
end

def send_scheduled_notifications()
  env = {"rack.moneta_store" => Moneta.new(:File, dir: File.join(Dir.tmpdir(), ".cache"))}
  api = get_bandwidth_api()
  db = get_db(env)
  now = DateTime.now
  now = DateTime.new(now.year, now.month, now.day, now.hour, now.min)
  reminders = db["Reminder"].find({time: {"$lte" => now}, enabled: true, completed: false}).to_a()
  puts "Sending scheduled notifications for #{reminders.size} reminders"
  for r in reminders
    id = r["_id"].to_s()
    user =  db["User"].find({_id: r["user"]}, {limit: 1}).first
    case r["notificationType"]
      when "Sms" then
        puts "Sending SMS for reminder #{r["name"]} (#{id})"
        Bandwidth::Message.create(api, {from: get_service_phone_number(env), to: user["phoneNumber"], text: r["content"]})
      when "Call" then
        puts "Making call for reminder #{r["name"]} (#{id})"
        host =  db["HostData"].find({}, {limit: 1}).first
        raise "Missing host information. Please open any page of this app first." unless host
        Bandwidth::Call.create(api, {from: get_service_phone_number(env), to: user["phoneNumber"], tag: r["content"], callback_url: "#{host["protocol"]}://#{host["host"]}/bandwidth/call-callback"})
      else
        puts "Unknown notification type #{r["notificationType"]}"
    end
    case r["repeat"]
      when "Once" then
        puts "Completing one time reminder #{r["name"]} (#{id})"
        db["Reminder"].update_one({_id: r["_id"]}, {"$set" => {completed: true}})
      when "Daily" then
        puts "Sheduling new time for reminder #{r["name"]} (#{id}) (1d)"
        db["Reminder"].update_one({_id: r["_id"]}, {"$set" => {time: add_days(r["time"], 1)}})
      when "Weekly" then
        puts "Sheduling new time for reminder #{r["name"]} (#{id}) (7d)"
        db["Reminder"].update_one({_id: r["_id"]}, {"$set" => {time: add_days(r["time"], 7)}})
      when "Monthly" then
        puts "Sheduling new time for reminder #{r["name"]} (#{id}) (1M)"
        db["Reminder"].update_one({_id: r["_id"]}, {"$set" => {time: add_months(r["time"], 1)}})
    end
  end
end

loop do
  begin
    send_scheduled_notifications()
  rescue => exception
    put exception
  end
  sleep 60
end
