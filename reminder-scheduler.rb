require "bundler"
Bundler.require
require "./helper"

require "date"
def add_days(time, days)
  time.to_date.next_day(days).to_time
end

def add_months(time, months)
  time.to_date.next_month(months).to_time
end

def send_scheduled_notifications()
  env = {}
  api = get_bandwidth_api()
  db = get_db(env)
  now = prepare_time(Time.now())
  reminders = db["Reminder"].find({time: {"$lte" => now}, enabled: true, completed: false}).to_a()
  put "Sending scheduled notifications for #{reminders.length} reminders"
  for r in reminders
    user =  db["User"].find({_id: r["user"]}, {limit: 1}).first
    case r["notificationType"]
      when "Sms" then
        put "Sending SMS for reminder #{r["name"]} (#{r["id"]})"
        Bandwidth::Message.create(api, {from: get_service_phone_number(env), to: user["phoneNumber"], text: r["content"]})
      when "Call" then
        put "Making call for reminder #{r["name"]} (#{r["id"]})"
        host =  db["HostData"].find({}, {limit: 1}).first
        raise "Missing host information. Please open any page of this app first." unless host
        Bandwidth::Call.create(api, {from: get_service_phone_number(env), to: user["phoneNumber"], tag: r["content"], callback_url: "#{host["protocol"]}://#{host["host"]}/bandwidth/call-callback"})
      else
        put "Unknown notification type #{r["notificationType"]}"
    end
    case r["repeat"]
      when "Once" then
        put "Completing one time reminder #{r["name"]} (#{r["id"]})"
        db["Reminder"].update({_id: r["_id"]}, {"$set" => {completed: true}})
      when "Daily" then
        put "Sheduling new time for reminder #{r["name"]} (#{r["id"]}) (1d)"
        db["Reminder"].update({_id: r["_id"]}, {"$set" => {time: add_days(r["time"], 1)}})
      when "Weekly" then
        put "Sheduling new time for reminder #{r["name"]} (#{r["id"]}) (7d)"
        db["Reminder"].update({_id: r["_id"]}, {"$set" => {time: add_days(r["time"], 7)}})
      when "Monthly" then
        put "Sheduling new time for reminder #{r["name"]} (#{r["id"]}) (1M)"
        db["Reminder"].update({_id: r["_id"]}, {"$set" => {time: add_months(r["time"], 1)}})
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
