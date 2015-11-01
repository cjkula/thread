# app.rb
require 'rubygems'
require 'sinatra'
require 'mongo_mapper'
require 'json/ext' # required for .to_json

APP_NAME = 'Thread'
ROOT_DIR = File.dirname(__FILE__)

# add to load path
$:.unshift ROOT_DIR,
           File.join(ROOT_DIR, 'lib'),
           File.join(ROOT_DIR, 'models'),
           File.join(ROOT_DIR, 'routes')

# load models and routes
Dir.glob(File.join(ROOT_DIR, 'models', '**/*.rb')) { |file| require file }
Dir.glob(File.join(ROOT_DIR, 'routes', '**/*.rb')) { |file| require file }

configure do
  env = settings.environment.to_s
  uri = ENV['MONGOLAB_URI'] || 'mongodb://127.0.0.1:27017'
  MongoMapper.setup({env => {'uri' => uri}}, env)
  MongoMapper.database = "#{APP_NAME.downcase}_#{env}"
end

class MyApp < Sinatra::Base
  before 'api/**/*.json' do
    content_type 'application/json'
  end
end
