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
  get_from_cache env, "user:#{number}", lambda {
    db["User"].find({phoneNumber: number}, {limit: 1}).first
  }
end
