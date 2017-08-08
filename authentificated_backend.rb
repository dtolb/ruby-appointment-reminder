require "./helper"

class AuthentificatedBackend
  def initialize(app)
    @app = app
  end

  def call(env)
    if env[:user]
      @app.call(env)
    else
      status 401
    end
  end
end
