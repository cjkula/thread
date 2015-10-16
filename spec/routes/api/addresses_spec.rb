require 'spec_helper'
require 'conversions'
require 'json'
include Conversions

describe 'GET /api/addresses/generate' do
  it "should return a valid private/public key pair" do
    address = Address.new.generate
    allow(Address).to receive(:new).and_return(address)
    get '/api/addresses/generate'
    data = JSON.parse(last_response.body)
    expect(data['public_key']).to eq(address.public_key)
    expect(data['private_key']).to eq(address.private_key)
    expect(data['address_hex']).to eq(bytes_to_hex(address.public_address))
    expect(data['address_base58']).to eq(encode_base58(address.public_address))
  end
end
