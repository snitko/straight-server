# encoding: utf-8

require 'rubygems'
require 'bundler'
require 'rake'

begin
  Bundler.setup(:default, :development, :test)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

Dir.glob('lib/tasks/*.rake').each { |r| load r }

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://guides.rubygems.org/specification-reference/ for more options
  gem.name = "straight-server"
  gem.homepage = "http://github.com/snitko/straight-server"
  gem.license = "MIT"
  gem.summary = %Q{A Bitcoin payment gateway server: a state server for the stateless Straight library}
  gem.description = %Q{Accepts orders via http, returns payment info via http or streams updates via websockets, stores orders in a DB}
  gem.email = "roman.snitko@gmail.com"
  gem.authors = ["Roman Snitko"]
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
  task default: :spec
rescue LoadError
  # no rspec available
end
