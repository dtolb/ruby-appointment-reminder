def get_from_cache(env, key, action)
  cache = env["rack.moneta_store"]
  item = cache[key]
  return item if item
  item = action.call()
  cache[key] = item
  item
end

def get_user_by_number(env, number)
  db = env["database"]
  number = number.gsub(/([\s()-])/g, "");
  number = "+1#{number}" if number.length == 10
  number = "+#{number}" unless number.first == "+"
  db["User"].find({phoneNumber: number}, {limit: 1}).first
end

def get_bandwidth_api()
  Bandwidth::Client.new(ENV["BANDWIDTH_USER_ID"], ENV["BANDWIDTH_API_TOKEN"], ENV["BANDWIDTH_API_SECRET"])
end

def prepare_time(time)
  t = Time.parse(time)
  Time.mktime(t.year, t.month, t.day, t.hour, t.min)
end

def get_service_phone_number(env)
  api = get_bandwidth_api()
  get_from_cache env, "servicePhoneNumber", lambda {
    existingNumber = Bandwidth::PhoneNumber. list(api, {name: "Appointment Reminder Service Number"}).first
    return existingNumber[:number] if existingNumber
    number = Bandwidth::AvailableNumber.search_local(api, {areaCode: ENV["AREA_CODE"] || "910", quantity: 1}).first["number"]
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
  Bandwidth::Message.create(api, {from: get_service_phone_number(), to: user["phoneNumber"], text: "Your verification code: #{code}"})
  db = env["database"]
  db["User"].update({_id: user["_id"]}, {"$set" => {verificationCode: code}})
end
