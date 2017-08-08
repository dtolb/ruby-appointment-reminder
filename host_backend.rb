require "./helper"

class HostBackend
  def initialize(app)
    @app = app
  end

  def call(env)
    db = env["database"]
    db["HostData"].update({}, {host: env["SERVER_NAME"], protocol: env["SERVER_PROTOCOL"]}, {upsert: true})
    @app.call(env)
  end
end
