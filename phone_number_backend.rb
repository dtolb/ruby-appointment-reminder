require "./helper"

class PhoneNumberBackend
  def initialize(app)
    @app = app
  end

  def call(env)
    session = env["rack.session"]
    env[:user] = get_user_by_number(env, session[:user_phone_number])
    @app.call(env)
  end
end
