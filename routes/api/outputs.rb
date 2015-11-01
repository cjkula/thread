require 'json'
require 'conversions'
include Conversions

def decorate_output(output)
  {
    transactionUid: output.transaction_uid,
    outputType:      output.output_type,
    value:          output.value,
    root:           bytes_to_hex(output.root),
    asset:          bytes_to_hex(output.asset),
    script:         output.script.humanize,
    scriptHex:      bytes_to_hex(output.script.serialize)
  }
end

def preprocess_params
  if (addresses = params.delete('addresses') || params.delete(:addresses))
    params['addresses'] = addresses.split(',')
  end
  if (identities = params.delete('identities') || params.delete(:identities))
    params['identities'] = identities.split(',')
  end
  params
end

def format_outputs(outputs)
  outputs.map { |output| decorate_output(output) }.to_json
end

get '/api/outputs.json' do
  format_outputs(Output.where(preprocess_params))
end

get '/api/values.json' do
  format_outputs(Output.with(:value, preprocess_params))
end

get '/api/assets.json' do
  format_outputs(Output.with(:asset, preprocess_params))
end

get '/api/identities.json' do
  format_outputs(Output.identities(preprocess_params))
end

get "/api/identities/:uid.json" do
  identity = Output.identity(hex_to_bytes(params[:uid])) # use Output::identities method
  (identity ? decorate_output(identity) : { error: 'Output::NotFound' }).to_json
end
