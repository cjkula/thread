require 'sinatra'
require 'rack/test'
require 'database_cleaner'

set :environment, :test

require File.join(File.dirname(__FILE__), '../app.rb')

RSpec.configure do |config|
  config.include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  config.before(:suite) do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean_with :truncation
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end
