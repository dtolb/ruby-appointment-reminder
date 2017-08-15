require_relative "../reminder_scheduler"

def wrap(collection)
  stub = double()
  allow(stub).to receive(:create_many).with(anything())
  allow(collection).to receive(:indexes).and_return(stub)
end

describe "send_scheduled_notifications" do
  before :each do
    double("Mongo::Client")
    @db = create_db()
    ENV["BANDWIDTH_USER_ID"] = "userId"
    ENV["BANDWIDTH_API_TOKEN"] = "token"
    ENV["BANDWIDTH_API_SECRET"] = "secret"
    allow(Mongo::Client).to receive(:new).and_return @db
    wrap(@db["User"])
    wrap(@db["Reminder"])
    double("Bandwidth::Message")
    double("Bandwidth::Call")
    double("Bandwidth::PhoneNumber")
    allow(Moneta).to receive(:new).with(any_args()).and_return({})
    allow(Bandwidth::PhoneNumber).to receive(:list).and_return(anything(), {name: "Appointment Reminder Service Number"}).and_return([{number: "+10234567890"}])
  end

  it "should send notifications" do
    now = DateTime.new(2017,8,15,8,1)
    allow(DateTime).to receive(:now).and_return(now)
    reminders = [
      {"_id" => "id1", "user" => "id1", "name" => "test1", "notificationType" => "Sms", "repeat" => "Once", "content" => "Message1", "time" => now},
      {"_id" => "id2", "user" => "id1", "name" => "test2", "notificationType" => "Call", "repeat" => "Daily", "content" => "Message2", "time" => now},
      {"_id" => "id3", "user" => "id1", "name" => "test3", "notificationType" => "Sms", "repeat" => "Weekly", "content" => "Message3", "time" => now},
      {"_id" => "id4", "user" => "id1", "name" => "test4", "notificationType" => "Sms", "repeat" => "Monthly", "content" => "Message4", "time" => now}
    ]
    allow(@db["Reminder"]).to receive(:find).with({time: {"$lte" => now}, enabled: true, completed: false}).and_return(reminders)
    allow(@db["User"]).to receive(:find).with({_id: "id1"}, {limit: 1}).and_return([{"phoneNumber" => "+10234567891"}])
    allow(@db["HostData"]).to receive(:find).with({}, {limit: 1}).and_return([{"host" => "host", "protocol" => "http"}])
    allow(Bandwidth::Call).to receive(:create).with(anything(), {from: "+10234567890", to: "+10234567891", tag: "Message2", callback_url: "http://host/bandwidth/call-callback"})
    allow(Bandwidth::Message).to receive(:create).with(anything(), {from: "+10234567890", to: "+10234567891", text: /Message\d/})
    allow(@db["Reminder"]).to receive(:update_one).with({_id: "id1"}, {"$set" => {completed: true}}).once
    allow(@db["Reminder"]).to receive(:update_one).with({_id: "id2"}, {"$set" => {time: DateTime.new(2017,8,16,8,1)}}).once
    allow(@db["Reminder"]).to receive(:update_one).with({_id: "id3"}, {"$set" => {time: DateTime.new(2017,8,22,8,1)}}).once
    allow(@db["Reminder"]).to receive(:update_one).with({_id: "id4"}, {"$set" => {time: DateTime.new(2017,9,15,8,1)}}).once
    send_scheduled_notifications()
  end
end
