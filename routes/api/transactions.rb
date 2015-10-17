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

def transaction_to_json(transaction)
  inputs = transaction.inputs.map do |input|
    {
      transactionUid: bytes_to_hex(input.transaction_uid),
      outputIndex:    input.output_index,
      script:         input.script.humanize,
      scriptHex:      bytes_to_hex(input.script.serialize)
    }
  end

  outputs = transaction.outputs.map do |output|
    {
      assetType: output.asset_type,
      value:     output.value,
      asset:     output.asset ? bytes_to_hex(output.asset) : nil,
      script:    output.script.humanize,
      scriptHex: bytes_to_hex(output.script.serialize)
    }
  end

  {
    uid:     transaction.uid,
    inputs:  inputs,
    outputs: outputs,
    raw:     bytes_to_hex(transaction.serialize)
  }.to_json
end

get '/api/transactions.json' do
  content_type :json
  Transaction.all.map { |transaction| { uid: transaction.uid } }.to_json
end

get '/api/transactions/count' do
  content_type :json
  Transaction.count.to_json
end

get '/api/transactions/:uid.json' do
  content_type :json
  transaction = Transaction.first(uid: params[:uid])
  transaction.deserialize
  transaction_to_json(transaction)
end

post '/api/transactions.json' do
  content_type :json
  transaction = Transaction.new

  (params[:inputs] || []).each do |input|
    transaction.inputs << Input.new(parse_script(integerize([:output_index], input)))
  end

  (params[:outputs] || []).each do |output|
    transaction.outputs << Output.new(parse_script(integerize([:value, :asset_type], parse_asset_info(output))))
  end

  begin
    transaction.validate
    transaction.save
    transaction_to_json(transaction)
  rescue StandardError => e
    status 400
    { error: e.class.to_s }.to_json
  end

end
