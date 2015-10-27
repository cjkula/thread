require 'conversions'
include Conversions

post '/api/addresses/generate.json' do
  content_type :json
  document = Document.create(request.body.read.to_s)
  { uid:  document.uid }.to_json
end
