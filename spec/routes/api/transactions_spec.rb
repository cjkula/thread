require 'spec_helper'
require 'conversions'
include Conversions

describe '/api/transactions' do
  describe 'GET' do
    it "should return a list of transaction uids" do
      allow_any_instance_of(TransactionValidator).to receive(:valid?).and_return(true)
      t1 = Transaction.new; t1.validate; t1.save
      t2 = Transaction.new; t2.validate; t2.save
      get '/api/transactions.json'
      expect(JSON.parse(last_response.body)).to eq([{'uid' => t1.uid}, {'uid' => t2.uid}])
    end
  end

  describe 'GET count' do
    it "should return the number of transactions in the database" do
      allow_any_instance_of(TransactionValidator).to receive(:valid?).and_return(true)
      t1 = Transaction.new; t1.validate; t1.save
      t2 = Transaction.new; t2.validate; t2.save

      get '/api/transactions/count'
      expect(last_response.body).to eq(Transaction.count.to_s)
    end
  end

  describe "GET /api/transactions/:uid.json" do
    it "should retrieve the transaction in JSON format" do
      prev_transaction_uid = Transaction.new.calculate_uid('fake_transaction')
      input = Input.new(transaction_uid: prev_transaction_uid, output_index: 1, script: Script.new(['xyz']))
      output = Output.new(value: 1, script: Script.new(['ZYX']))
      transaction = Transaction.new(inputs: [input], outputs: [output])
      allow_any_instance_of(TransactionValidator).to receive(:valid?).and_return(true)
      transaction.validate
      transaction.save

      get "/api/transactions/#{transaction.uid}.json"
      result = JSON.parse(last_response.body)
      expect(result['uid']).to eq(transaction.uid)
      expect(result['inputs']).to eq([{"transactionUid"=>"c62448673f37ee2e0a0653df70c75c2cf697ee7f", "outputIndex"=>1, "script"=>bytes_to_hex("xyz").upcase, "scriptHex"=>"00040378797a"}])
      expect(result['outputs']).to eq([{"assetType"=>1, "value"=>1, "asset"=>nil, "script"=>bytes_to_hex("ZYX").upcase, "scriptHex"=>"0004035a5958"}])
      expect(result['raw']).to eq(bytes_to_hex(transaction.serialize))
    end
  end

  describe "POST" do
    def transaction_post_and_fetch(params)
      post '/api/transactions.json', params
      expect(last_response).to be_ok
      transaction = nil
      10.times do
        # often will fail the first times attempted: retry until the previous write commits
        transaction = Transaction.last(uid: JSON.parse(last_response.body)['uid'])
        break if transaction
      end
      transaction.deserialize
      transaction
    end

    context "with valid params" do
      before do
        allow_any_instance_of(TransactionValidator).to receive(:valid?).and_return(true)
      end

      it "should return the transaction" do
        post '/api/transactions.json', {}
        transaction = Transaction.last
        expect(last_response.body).to eq({ uid: transaction.uid, inputs: [], outputs: [], raw: '00000000' }.to_json)
      end
      it "should create an empty transaction record" do
        t = transaction_post_and_fetch({})
        expect(t.inputs).to eq([])
        expect(t.outputs).to eq([])
      end
      it "should create a transaction with a value output" do
        script_bytes = Script.new([:op_dup]).serialize
        t = transaction_post_and_fetch(outputs: [{ value: 100, script: bytes_to_hex(script_bytes) }])
        expect(t.inputs).to eq([])
        expect(t.outputs.length).to eq(1)
        output = t.outputs[0]
        expect(output.value).to eq(100)
        expect(output.asset_type).to eq(Output::VALUE_ASSET_TYPE)
        expect(output.asset).to be_nil
        expect(output.script).to eq([:op_dup])
      end
      it "should create a transaction with an asset output" do
        script_bytes = Script.new([:op_verify]).serialize
        asset = sha256('something')
        t = transaction_post_and_fetch(outputs: [{ asset_type: 'SHA256', asset: bytes_to_hex(asset), script: bytes_to_hex(script_bytes) }])
        expect(t.inputs).to eq([])
        expect(t.outputs.length).to eq(1)
        output = t.outputs[0]
        expect(output.value).to be_nil
        expect(output.asset_type).to eq(Output::SHA256_ASSET_TYPE)
        expect(output.asset).to eq(asset)
        expect(output.script).to eq([:op_verify])
      end
      it "should create a transaction with an input" do
        script_bytes = Script.new(['XYZPDQ']).serialize
        prev_transaction_uid = Transaction.new.calculate_uid('fake_content')
        t = transaction_post_and_fetch(inputs: [{ transaction_uid: prev_transaction_uid, output_index: 1, script: bytes_to_hex(script_bytes) }])
        expect(t.inputs.length).to eq(1)
        input = t.inputs[0]
        expect(input.transaction_uid).to eq(prev_transaction_uid)
        expect(input.output_index).to eq(1)
        expect(input.script).to eq(['XYZPDQ'])
        expect(t.outputs).to eq([])
      end
      it "should create a transaction with multiple inputs and outputs" do
        uid1 = Transaction.new.calculate_uid('fake_content')
        uid2 = Transaction.new.calculate_uid('more_fake_content')
        script1_hex = bytes_to_hex(Script.new(['test1']).serialize)
        script2_hex = bytes_to_hex(Script.new(['test2']).serialize)
        script3_hex = bytes_to_hex(Script.new(['test3']).serialize)
        script4_hex = bytes_to_hex(Script.new(['test4']).serialize)
        asset = sha256('something')

        params = {
          inputs: [
            { transaction_uid: uid1, output_index: 10, script: script1_hex },
            { transaction_uid: uid2, output_index: 3, script: script2_hex }
          ],
          outputs: [
            # weird things happen if :value is not nil'd here -- the :value => 12 from
            # the subsequent hash somehow gets moved to this one when params are parsed
            { value: nil, asset_type: 'SHA256', asset: bytes_to_hex(asset), script: script3_hex },
            { value: 12, script: script4_hex }
          ]
        }

        t = transaction_post_and_fetch(params)

        expect(t.inputs.length).to eq(2)
        expect(t.outputs.length).to eq(2)
        expect(bytes_to_hex(t.inputs[0].serialize)).to eq(bytes_to_hex(uid1) + '000a' + script1_hex)
        expect(bytes_to_hex(t.inputs[1].serialize)).to eq(bytes_to_hex(uid2) + '0003' + script2_hex)
        expect(bytes_to_hex(t.outputs[0].serialize)).to eq(hex8(Output::SHA256_ASSET_TYPE) + bytes_to_hex(asset) + script3_hex)
        expect(bytes_to_hex(t.outputs[1].serialize)).to eq(hex8(12) + script4_hex)
      end
    end

    context "with invalid params" do
      it "should return the error information" do
        allow_any_instance_of(TransactionValidator).to receive(:valid?).and_raise(Input::MissingScript)
        post '/api/transactions.json', {}
        expect(last_response.status).to eq(400)
        expect(JSON.parse(last_response.body)['error']).to eq('Input::MissingScript')
      end
    end

  end
end

