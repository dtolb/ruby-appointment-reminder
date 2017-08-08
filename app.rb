require "bundler"
Bundler.require

require "rack/moneta_store"

require "./phone_number_backend"
require "./database_backend"
require "./host_backend"
require "./helper"

class AppointmentReminderApp < Sinatra::Base
  enable :sessions
  use Rack::PostBodyContentTypeParser
  use Rack::MonetaStore, :File, :dir => File.join(Dir.tmpdir(), ".cache")
  use DatabaseBackend
  use PhoneNumberBackend
  use HostBackend

  set :public_dir, File.join(File.dirname(__FILE__), "public")

  get "/" do
    redirect "/index.html"
  end
end
