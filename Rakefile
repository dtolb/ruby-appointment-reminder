require 'rspec/core/rake_task'
require_relative "./reminder_scheduler"

RSpec::Core::RakeTask.new(:spec)

task :test => :spec

task :build do
  `yarn install && yarn run build`
end

task :web do
  puts "Starting a web application"
  `bundle exec puma -p $PORT`
end

task :sheduler do
  loop do
    puts "Starting a scheduler"
    begin
      send_scheduled_notifications()
    rescue => exception
      put exception
    end
    sleep 60
  end
end

multitask :default => [:sheduler, :web]
