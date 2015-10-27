require 'spec_helper'
require 'conversions'
require 'json'
include Conversions

describe 'POST /api/documents' do
  it "should create a new document" do
    post '/api/documents', "Content-Type: text/plain\n\ntesting"
    document = Document.where(uid: JSON.parse(last_response.body).uid).first
    expect(document.content_type).to eq('text/plain')
    expect(document.body).to eq('testing')
  end
  it "should return a JSON document with the UID of the created document"
  it "should not create a document that already exists"
  it "should return a JSON document with the UID of an existing identical document"
  it "should recognize an identity document"
end
