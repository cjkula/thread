require 'json'

def integerize(value)
  value ? value.to_i : nil
end

def parse_output_type(output_type)
  case output_type.downcase
  when /\A\d+\z/      then output_type.to_i
  when 'value'        then Output::VALUE
  when 'sha256'       then Output::SHA256
  when 'sha256-root'  then Output::SHA256_ROOT
  when 'sha256-head'  then Output::SHA256_HEAD
  when 'rmd160'       then Output::RMD160
  when 'rmd160-root'  then Output::RMD160_ROOT
  when 'rmd160-head'  then Output::RMD160_HEAD
  when 'hash160'      then Output::HASH160
  when 'hash160-root' then Output::HASH160_ROOT
  when 'hash160-head' then Output::HASH160_HEAD
  else nil
  end
end

def transaction_to_json(transaction)
  inputs = transaction.inputs.map do |input|
    {
      outputTransaction: bytes_to_hex(input.output_transaction),
      outputIndex:       input.output_index,
      script:            input.script.humanize,
      scriptHex:         bytes_to_hex(input.script.serialize(false))
    }
  end

  outputs = transaction.outputs.map do |output|
    {
      outputType: output.output_type,
      value:     output.value,
      root:     bytes_to_hex(output.root),
      asset:     bytes_to_hex(output.asset),
      script:    output.script.humanize,
      scriptHex: bytes_to_hex(output.script.serialize(false))
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
  Transaction.all.map { |transaction| { uid: transaction.uid } }.to_json
end

get '/api/transactions/count.json' do
  Transaction.count.to_json
end

get '/api/transactions/:uid.json' do
  transaction = Transaction.first(uid: params[:uid])
  transaction.deserialize
  transaction_to_json(transaction)
end

post '/api/transactions.json' do
  tx_params = JSON.parse(request.body.read)

  transaction = Transaction.new

  transaction.inputs = (tx_params['inputs'] || []).map do |attrs|
    Input.new output_transaction:      hex_to_bytes(attrs['outputTransaction']),
              output_index:     integerize(attrs['outputIndex']),
              script:                    Script.import_human_readable(attrs['script'])
  end
  transaction.outputs = (tx_params['outputs'] || []).map do |attrs|
    Output.new output_type:      attrs['outputType'] ? parse_output_type(attrs['outputType']) : nil,
               value:           integerize(attrs['value']),
               root:            hex_to_bytes(attrs['root']),
               asset:           hex_to_bytes(attrs['asset']),
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
