describe DatabaseBackend do
  before :each do
    double("Mongo::Client")
  end

  it "should return return database instance" do
    allow(Mongo::Client).to receive(:new) { {} }
    cache = {"db:#{ENV["DATABASE_URL"] || "mongodb://localhost/appointment-reminder"}" => {}}
    env = create_env({}, cache)
    backend = DatabaseBackend.new(create_app())
    backend.call(env)
    expect(env["database"]).not_to be_nil
  end
  it "should create indexes" do
    get_mock_collection = Proc.new do |name|
      indexes = double("#{name}Indexes")
      c = double("#{name}Collection")
      allow(c).to receive(:indexes) {indexes}
      allow(indexes).to receive(:create_many).with(any_args).once
      c
    end
    client = {
      "User" => get_mock_collection.call("User"),
      "Reminder" => get_mock_collection.call("Reminder")
    }
    allow(Mongo::Client).to receive(:new) { client }
    env = create_env()
    backend = DatabaseBackend.new(create_app())
    backend.call(env)
  end
end
