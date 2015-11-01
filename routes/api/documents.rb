require 'conversions'
include Conversions

post '/api/documents.json' do
  document = Document.create(request.body.read.to_s)
  { uid:  document.uid }.to_json
end

get '/api/documents.json' do
  Document.all.to_json
end

get '/api/documents/:uid.json' do
  document = Document.first(uid: params[:uid])
  document.body.to_json
end
