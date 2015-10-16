require 'conversions'
include Conversions

get '/api/addresses/generate' do
  content_type :json
  address = Address.new.generate
  {
    public_key:     address.public_key,
    private_key:    address.private_key,
    address_hex:    bytes_to_hex(address.public_address),
    address_base58: encode_base58(address.public_address)
  }.to_json
end
