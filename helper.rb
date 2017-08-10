require "date"

Mongo::Logger.logger.level = ::Logger::FATAL


def get_from_cache(env, key, action)
  cache = env["rack.moneta_store"]
  item = cache[key]
  return item if item
  item = action.call()
  cache[key] = item
  item
end

def get_db(env)
  url = ENV["DATABASE_URL"] || ENV["MONGODB_URI"] || "mongodb://localhost/appointment-reminder"
  db = Mongo::Client.new(url)
  if env
    get_from_cache env, "db:#{url}", lambda {
      # Call only once
      db["User"].indexes().create_many([
        { key: { name: 1 }},
        { key: { phoneNumber: 1 }}
      ])
      db["Reminder"].indexes().create_many([
        { key: { name: 1 }},
        { key: { createdAt: -1 }},
        { key: { enabled: 1 }},
        { key: { user: 1 }}
      ])
      url
    }
  end
  db
end

def get_user_by_number(env, number)
  db = env["database"]
  number = (number || "").gsub(/([\s()-])/, "");
  number = "+1#{number}" if number.length == 10
  number = "+#{number}" unless number.start_with?("+")
  db["User"].find({phoneNumber: number}, {limit: 1}).first
end

def get_bandwidth_api()
  Bandwidth::Client.new(ENV["BANDWIDTH_USER_ID"], ENV["BANDWIDTH_API_TOKEN"], ENV["BANDWIDTH_API_SECRET"])
end

def prepare_time(time)
  t = Time.parse(time)
  DateTime.new(t.year, t.month, t.day, t.hour, t.min)
end

def get_service_phone_number(env)
  api = get_bandwidth_api()
  get_from_cache env, "servicePhoneNumber", lambda {
    existingNumber = Bandwidth::PhoneNumber.list(api, {name: "Appointment Reminder Service Number"}).first
    return existingNumber[:number] if existingNumber
    number = Bandwidth::AvailableNumber.search_local(api, {areaCode: ENV["AREA_CODE"] || "910", quantity: 1}).first[:number]
    Bandwidth::PhoneNumber.create(api, {number: number, name: "Appointment Reminder Service Number"})
    number
  }
end


def send_verification_code(env, number)
  api = get_bandwidth_api()
  rand = Random.new()
  user = get_user_by_number(env, number)
  return unless user
  code = (rand.rand(9000) + 1000).to_s()
  Bandwidth::Message.create(api, {from: get_service_phone_number(env), to: user["phoneNumber"], text: "Your verification code: #{code}"})
  db = env["database"]
  db["User"].update_one({_id: user["_id"]}, {"$set" => {verificationCode: code}})
end
