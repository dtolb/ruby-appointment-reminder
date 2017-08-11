require "./helper"

class HostBackend
 def initialize(app)
   @app = app
 end

 def call(env)
   db = env["database"]
   db["HostData"].update_one({}, {host: env["SERVER_NAME"], protocol: env["HTTP_X_FORWARDED_PROTO"] || env["rack.url_scheme"]}, {upsert: true})
   @app.call(env)
 end
end
