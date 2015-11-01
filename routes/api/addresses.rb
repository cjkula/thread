require 'conversions'
include Conversions

get '/api/addresses/generate.json' do
  address = Address.new.generate
  {
    publicKey:  address.public_key,
    privateKey: address.private_key,
    hex:        bytes_to_hex(address.public_address),
    base58:     encode_base58(bytes_to_hex(address.public_address))
  }.to_json
end
