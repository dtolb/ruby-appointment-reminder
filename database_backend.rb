require "./helper"

class DatabaseBackend
  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env) if env["database"]
    env["database"] = get_db(env)
    @app.call(env)
  end
end
