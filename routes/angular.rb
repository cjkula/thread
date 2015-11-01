require 'seed'

get '/explorer' do
  erb :explorer
end

get '/spool' do
  erb :spool
end

get '/seed' do
  erb :spool_seed
end

get '/spool/seed.json' do
  begin
    Seed.spool.map do |address|
      {
        publicKey:  address.public_key,
        privateKey: address.private_key,
        hex:        bytes_to_hex(address.public_address),
        base58:     encode_base58(bytes_to_hex(address.public_address))
      }
    end.to_json
  rescue Exception => e
    status 500
    {
      error: e.message,
      backtrace: e.backtrace
    }.to_json
  end
end
