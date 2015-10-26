require 'json'

def integerize(value)
  value ? value.to_i : nil
end

def parse_asset_type(asset_type)
  case asset_type.downcase
  when /\A\d+\z/
    asset_type.to_i
  when 'value'
    Output::VALUE_ASSET_TYPE
  when 'sha256'
    Output::SHA256_ASSET_TYPE
  end
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
  tx_params = JSON.parse(request.body.read)

  transaction = Transaction.new

  transaction.inputs = (tx_params['inputs'] || []).map do |attrs|
    Input.new transaction_uid: hex_to_bytes(attrs['transactionUid']),
              output_index:    integerize(attrs['outputIndex']),
              script:          Script.import_human_readable(attrs['script'])
  end
  transaction.outputs = (tx_params['outputs'] || []).map do |attrs|
    Output.new asset_type:      attrs['assetType'] ? parse_asset_type(attrs['assetType']) : nil,
               value:           integerize(attrs['value']),
               asset:           attrs['asset'] ? hex_to_bytes(attrs['asset']) : nil,
               script:          Script.import_human_readable(attrs['script'])
  end

  begin
    transaction.validate
    transaction.save
    transaction_to_json(transaction)
  rescue StandardError => e
    status 400
    error = { error: e.class.to_s }
    if [:development, :test].include?(settings.environment)
      error.merge!(message: e.message, backtrace: [e.backtrace[0]] + e.backtrace[1..-1].select { |line| line =~ /thread/})
    end
    error.to_json
  end

end
