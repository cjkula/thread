require 'spec_helper'
require 'conversions'
require 'json'
include Conversions

describe 'GET /api/addresses/generate' do
  it "should return a valid private/public key pair" do
    address = Address.new.generate
    allow(Address).to receive(:new).and_return(address)
    get '/api/addresses/generate.json'
    data = JSON.parse(last_response.body)
    expect(data['publicKey']).to eq(address.public_key)
    expect(data['privateKey']).to eq(address.private_key)
    expect(data['hex']).to eq(bytes_to_hex(address.public_address))
    expect(data['base58']).to eq(encode_base58(bytes_to_hex(address.public_address)))
  end
end
