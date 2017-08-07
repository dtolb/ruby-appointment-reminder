require "bundler"
Bundler.require

require "rack/moneta_store"

require "./websocket_backend"
require "./database_backend"
require "./helper"

class CallTrackingApp < Sinatra::Base
  use Rack::PostBodyContentTypeParser
  use Rack::MonetaStore, :File, :dir => File.join(Dir.tmpdir(), ".cache")
  use DatabaseBackend

  set :public_dir, File.join(File.dirname(__FILE__), "public")

  get "/" do
    redirect "/index.html"
  end
end
