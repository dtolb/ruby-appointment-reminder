require "json"
describe AppointmentReminderApp do

  before :each do
    double("Bandwidth::Call")
    @db = create_db()
    allow(@db["HostData"]).to receive(:update_one).with(any_args())
    allow(@db["User"]).to receive(:find).with({phoneNumber: "+1234567891"}, {limit: 1}).and_return [{"phoneNumber" => "+1234567891", "verificationCode" => "1000", "_id" => "id"}]
    allow(@db["User"]).to receive(:find).with(any_args()).and_return []
    ENV["BANDWIDTH_USER_ID"] = "userId"
    ENV["BANDWIDTH_API_TOKEN"] = "token"
    ENV["BANDWIDTH_API_SECRET"] = "secret"
    @make_post_request = Proc.new do |path, data|
      env = create_env({"database" => @db})
      app = AppointmentReminderApp.new()
      json = data.to_json()
      env = Rack::MockRequest.env_for(path, {method: "POST", input: json, "CONTENT_LENGTH" => json.length.to_s, "CONTENT_TYPE" => "application/json"}).merge(env)
      app.call(env)
    end
  end

  it "should show index page on GET /" do
    env = create_env({"database" => @db, "SERVER_NAME" => "localhost"})
    env = Rack::MockRequest.env_for("/", {method: "GET"}).merge(env)
    app = AppointmentReminderApp.new()
    res = app.call(env)
    expect(res[0]).to eql(302)
    expect(res[1]["Location"].end_with?("/index.html")).to be true
  end

  describe "POST /register" do
    it "should register new user" do
      allow(@db["User"]).to receive(:insert_one).with(hash_including("phoneNumber" => "+1234567890"))
      @make_post_request.call("/register", {phoneNumber: "+1234567890"})
    end
  end

  describe "POST /login" do
    it "should send notification with code" do
      @make_post_request.call("/login", {phoneNumber: "+1234567891"})
    end
  end

  describe "POST /verify-code" do
    it "should check verification code" do
      allow(@db["User"]).to receive(:update_one).with({_id: "id"}, {"$set" => {verificationCode: nil}})
      @make_post_request.call("/verify-code", {phoneNumber: "+1234567891", code: "1000"})
    end
  end

  describe "POST /bandwidth/call-callback" do
    before :each do
      call = double()
      allow(call).to receive(:speak_sentence).with("Hello")
      allow(call).to receive(:hangup)
      allow(Bandwidth::Call).to receive(:new).with({id: "callId"}, anything()).and_return(call)
    end
    it "should handle event 'answer'" do
      @make_post_request.call("/bandwidth/call-callback", {callId: "callId", eventType: "answer", tag: "Hello"})
    end
    it "should handle event 'speak'" do
      @make_post_request.call("/bandwidth/call-callback", {callId: "callId", eventType: "speak", status: "done"})
    end
  end

  describe "GET /reminder" do
    it "should return reminders " do
      allow(@db["Reminder"]).to receive(:find).with({user: "id"}, {sort: {"createdAt" => -1}}).and_return([{}])
      env = create_env({"database" => @db})
      allow(@db["User"]).to receive(:find).with(any_args()).and_return [{"_id" => "id"}]
      app = AppointmentReminderApp.new()
      env = Rack::MockRequest.env_for("/reminder", {method: "GET"}).merge(env)
      r = app.call(env)
      expect(JSON.parse(r[2][0]).length).to eql(1)
    end
  end

  describe "POST /reminder" do
    it "should create a reminder" do
      allow(@db["User"]).to receive(:find).with(any_args()).and_return [{"_id" => "id"}]
      allow(@db["Reminder"]).to receive(:insert_one).with(anything())
      r = @make_post_request.call("/reminder", {name: "test", time: "2017-08-15T12:00:00Z"})
      expect(JSON.parse(r[2][0])["name"]).to eql("test")
    end
  end

  describe "POST /reminder/:id/enabled" do
    it "should switch flag enabled" do
      allow(@db["User"]).to receive(:find).with(any_args()).and_return [{"_id" => "id"}]
      id = BSON::ObjectId.new()
      allow(@db["Reminder"]).to receive(:update_one).with({_id: id, user: "id"}, {"$set" => {enabled: true}})
      r = @make_post_request.call("/reminder/#{id.to_s}/enabled", {enabled: "true"})
      expect(r[2][0]).to eql("")
    end
  end

  describe "DELETE /reminder/:id" do
    it "should remove user's reminder" do
      allow(@db["User"]).to receive(:find).with(any_args()).and_return [{"_id" => "id"}]
      id = BSON::ObjectId.new()
      allow(@db["Reminder"]).to receive(:delete_one).with({_id: id, user: "id"})
      env = create_env({"database" => @db})
      app = AppointmentReminderApp.new()
      env = Rack::MockRequest.env_for("/reminder/#{id.to_s}", {method: "DELETE"}).merge(env)
      r = app.call(env)
      expect(r[2][0]).to eql("")
    end
  end


end
