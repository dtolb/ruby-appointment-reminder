require "./helper"

Mongo::Logger.logger.level = ::Logger::FATAL

class DatabaseBackend
  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env) if env["database"]
    url = ENV["DATABASE_URL"] || ENV["MONGODB_URI"] || "mongodb://localhost/call-tracking"
    db = Mongo::Client.new(url)
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
    env["database"] = db
    @app.call(env)
  end
end
