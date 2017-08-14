describe "get_from_cache" do
  it "should return cached item" do
    env = create_env({}, {"test" => 11})
    res = get_from_cache(env, "test", lambda { 10 })
    expect(res).to eql(11)
  end
  it "should call action and save value in cache" do
    cache = {}
    env = create_env({}, cache)
    res = get_from_cache(env, "test", lambda { 10 })
    expect(res).to eql(10)
    expect(cache["test"]).to eql(10)
  end
end
describe "get_db" do
  it "should return database instance" do
    cache = {"db:mongodb://localhost/appointment-reminder" => {}}
    env = create_env({}, cache)
    db = get_db(env)
    expect(db).not_to be_nil
  end
end
describe "get_user_by_number" do
  it "should return user by phone number" do
    db = create_db()
    user = {}
    allow(db["User"]).to receive(:find).with({phoneNumber: "+100"}, {limit: 1}).and_return([user])
    env = create_env({"database" => db})
    expect(get_user_by_number(env, "+100")).to be(user)
  end
  it "should fix a phone number" do
    db = create_db()
    user = {}
    allow(db["User"]).to receive(:find).with({phoneNumber: "+11234567890"}, {limit: 1}).and_return([user])
    env = create_env({"database" => db})
    expect(get_user_by_number(env, "1234567890")).to be(user)
  end
  it "should add missing +" do
    db = create_db()
    user = {}
    allow(db["User"]).to receive(:find).with({phoneNumber: "+11234567891"}, {limit: 1}).and_return([user])
    env = create_env({"database" => db})
    expect(get_user_by_number(env, "11234567891")).to be(user)
  end
end
describe "get_bandwidth_api" do
  it "should return api instance" do
    ENV["BANDWIDTH_USER_ID"] = "userId"
    ENV["BANDWIDTH_API_TOKEN"] = "token"
    ENV["BANDWIDTH_API_SECRET"] = "secret"
    expect(get_bandwidth_api()).not_to be_nil
  end
end

describe "prepare_time" do
  it "should return time without minutes and seconds" do
    time = prepare_time("2017-08-14T06:42:30.115Z")
    expect(time.sec).to eql(0)
    expect(time.min).to eql(42)
    expect(time.hour).to eql(06)
  end
end

describe "get_service_phone_number" do
  before :each do
    ENV["BANDWIDTH_USER_ID"] = "userId"
    ENV["BANDWIDTH_API_TOKEN"] = "token"
    ENV["BANDWIDTH_API_SECRET"] = "secret"
    double("Bandwidth::PhoneNumber")
    double("Bandwidth::AvailableNumber")
  end

  it "should return service number (create new number)" do
    expect(Bandwidth::PhoneNumber).to receive(:list).with(anything(), {name: "Appointment Reminder Service Number"}).and_return([])
    expect(Bandwidth::AvailableNumber).to receive(:search_local).with(anything(), {areaCode: "910", quantity: 1}).and_return([{number: "+19101112233"}])
    expect(Bandwidth::PhoneNumber).to receive(:create).with(anything(), {number: "+19101112233", name: "Appointment Reminder Service Number"})
    env = create_env()
    expect(get_service_phone_number(env)).to eql("+19101112233")
  end

  it "should return service number (using existing number)" do
    expect(Bandwidth::PhoneNumber).to receive(:list).with(anything(), {name: "Appointment Reminder Service Number"}).and_return([{number: "+19101112234"}])
    env = create_env()
    expect(get_service_phone_number(env)).to eql("+19101112234")
  end
end

describe "send_verification_code" do
  before :each do
    ENV["BANDWIDTH_USER_ID"] = "userId"
    ENV["BANDWIDTH_API_TOKEN"] = "token"
    ENV["BANDWIDTH_API_SECRET"] = "secret"
    double("Bandwidth::Message")
    double("Bandwidth::PhoneNumber")
  end

  it "should send random code via SMS" do
    db = create_db()
    user = {"phoneNumber" => "+101", "_id" => "id"}
    expect(Bandwidth::PhoneNumber).to receive(:list).with(anything(), {name: "Appointment Reminder Service Number"}).and_return([{number: "+19101112235"}])
    expect(Bandwidth::Message).to receive(:create).with(anything(), {from: "+19101112235", to: "+101", text: "Your verification code: 1000"})
    allow_any_instance_of(Random).to receive(:rand).and_return(0)
    allow(db["User"]).to receive(:find).with({phoneNumber: "+101"}, {limit: 1}).and_return([user])
    allow(db["User"]).to receive(:update_one).with({_id: "id"}, {"$set" => {verificationCode: "1000"}})
    env = create_env({"database" => db})
    send_verification_code(env, "+101")
  end
end
