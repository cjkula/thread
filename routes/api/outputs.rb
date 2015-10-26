require 'json'
require 'conversions'
include Conversions

def all_outputs
  transactions = Transaction.all
  transactions.each(&:deserialize)
  transactions.map do |transaction|
    transaction.outputs.tap do |outputs|
      outputs.each do |output|
        output.transaction_uid = transaction.uid
      end
    end
  end.flatten
end

### Too generalized? ###
# def filtered_outputs(filter = {})
#   all_outputs.select do |outputs|
#     filter.keys.all? do |key|
#       desired = filter[key]
#       actual = t.send(key)
#       desired.is_a?(Array) ? desired.include?(actual) : (actual == desired)
#     end
#   end
# end

# filter only for public key(s) in outputs
def filtered_outputs(filter = {})
  if (addresses = filter[:addresses])
    hex_addresses = addresses.map { |a| decode_base58(a).downcase }
    all_outputs.select do |output|
# puts hex_addresses.inspect
# puts output.script.inspect
      (hex_addresses & output.script).length > 0
    end
  else
    all_outputs
  end
end

def outputs_with(field_name, filters = {})
  x = filtered_outputs(filters)
puts x.inspect
  y = x.select(&field_name)
puts y.inspect
  y
end

def format_output(output)
  {
    transactionUid: output.transaction_uid,
    assetType:      output.asset_type,
    value:          output.value,
    asset:          output.asset ? bytes_to_hex(output.asset) : nil,
    script:         output.script.humanize,
    scriptHex:      bytes_to_hex(output.script.serialize)
  }
end

get '/api/outputs.json' do
  content_type :json
  filtered_outputs(params).map { |o| format_output(o) }.to_json
end

get '/api/values.json' do
  content_type :json
  outputs_with(:value, params).map { |o| format_output(o) }.to_json
end

get '/api/assets.json' do
  content_type :json
  outputs_with(:asset, params).map { |o| format_output(o) }.to_json
end

