describe HostBackend do
  it "should update host and protocol" do
    db = create_db()
    env = create_env({"database" => db, "SERVER_NAME" => "host", "rack.url_scheme" => "http"})
    backend = HostBackend.new(create_app())
    allow(db["HostData"]).to receive(:update_one).with({}, {host: "host", protocol: "http"}, {upsert: true})
    backend.call(env)
  end
end
