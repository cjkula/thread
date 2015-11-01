require 'spec_helper'
require 'conversions'

include Conversions

describe Document do
  before do
    @headers = "MIME-Version: 1.0\nContent-Type: application/json\n\n"
    @body = "{ \"key1\" : \"value1\" }\n"
    @document = Document.new(@headers + @body)
  end
  it "should extract the content type" do
    expect(@document.content_type).to eq('application/json')
  end
  it "should extract the body length" do
    expect(@document.size).to eq(@body.length)
  end
  it "should calculate the UID based on the document with headers" do
    expect(@document.uid).to eq(bytes_to_hex(hash160(@headers + @body)))
  end
  it "should return the full document with headers" do
    expect(@document.content).to eq(@headers + @body)
  end
  it "should return just the headers" do
    expect(@document.headers).to eq(@headers)
  end
  it "should return just the body" do
    expect(@document.body).to eq(@body)
  end
  it "should be able to update just the headers" do
    new_headers = "MIME-Version: 1.0\nContent-Type: text/plain\n\n"
    @document.headers = new_headers
    expect(@document.content_type).to eq('text/plain')
    expect(@document.content).to eq(new_headers + @body)
    expect(@document.uid).to eq(bytes_to_hex(hash160(new_headers + @body)))
    expect(@document.size).to eq(@body.length)
  end
  it "should be able to update just the body" do
    new_body = "{ \"key2\" : \"value2\" }\n"
    @document.body = new_body
    expect(@document.content_type).to eq('application/json')
    expect(@document.content).to eq(@headers + new_body)
    expect(@document.uid).to eq(bytes_to_hex(hash160(@headers + new_body)))
    expect(@document.size).to eq(new_body.length)
  end
  it "should be able to update the full content" do
    new_headers = "MIME-Version: 1.0\nContent-Type: text/plain\n\n"
    new_body = "{ \"key3\" : \"value3\" }\n"
    @document.content = new_headers + new_body
    expect(@document.content_type).to eq('text/plain')
    expect(@document.content).to eq(new_headers + new_body)
    expect(@document.uid).to eq(bytes_to_hex(hash160(new_headers + new_body)))
    expect(@document.size).to eq(new_body.length)
  end
end
