require 'spec_helper'
require 'conversions'
require 'json'
include Conversions

describe 'POST /api/documents.json' do
  before do
    @document_count_before = Document.count
    @content = "Content-Type: text/plain\n\ntesting"
    post '/api/documents.json', @content
  end
  it "should create a new document" do
    document = Document.where(uid: JSON.parse(last_response.body)['uid']).first
    expect(document.content_type).to eq('text/plain')
    expect(document.body).to eq('testing')
    expect(Document.count).to eq(@document_count_before + 1)
  end
  it "should return a JSON document with the UID of the created document" do
    expect(JSON.parse(last_response.body)['uid']).to eq(bytes_to_hex(hash160(@content)))
  end
  it "should not create a document that already exists" do
    expect(Document.count).to eq(@document_count_before + 1)
    post '/api/documents.json', @content
    expect(Document.count).to eq(@document_count_before + 1)
  end
  it "should return the UID of an existing identical document" do
    uid1 = JSON.parse(last_response.body)['uid']
    post '/api/documents.json', @content
    expect(JSON.parse(last_response.body)['uid']).to eq(uid1)
  end
end
