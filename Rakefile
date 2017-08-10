require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

task :test => :spec

task :build do
  `npm install && npm run build`
end

task :web do
  `bundle exec puma -p $PORT`
end

task :sheduler do
  `ruby reminder_scheduler.rb`
end

multitask :default => [:sheduler, :web]
