require 'json'

def integerize(fields, obj)
  fields.each do |field|
    if (value = obj.delete(field.to_s))
      obj[field.to_s] = value.to_i
    end
  end
  obj
end

def parse_script(obj)
  if (bytes = obj.delete('script'))
    script = Script.new
    script.deserialize(hex_to_bytes(bytes))
    obj["script"] = script
  end
  obj
end

def parse_asset_info(obj)
  if (asset_type = obj.delete('asset_type'))
    if asset_type.downcase == 'sha256'
      obj['asset_type'] = Output::SHA256_ASSET_TYPE
      if (asset = obj.delete('asset'))
        obj['asset'] = hex_to_bytes(asset)
      end
    end
  end
  obj
end

get '/api/transactions/count' do
  content_type :json
  Transaction.count.to_json
end

post '/api/transactions' do
  content_type :json
  transaction = Transaction.new

  (params[:inputs] || []).each do |input|
    transaction.inputs << Input.new(parse_script(integerize([:output_index], input)))
  end

  (params[:outputs] || []).each do |output|
    transaction.outputs << Output.new(parse_script(integerize([:value, :asset_type], parse_asset_info(output))))
  end

  transaction.validate
  transaction.save
  transaction.uid
end
