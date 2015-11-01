require 'spec_helper'
require 'conversions'
include Conversions

describe '/api/transactions' do
  describe 'GET' do
    it "should return a list of transaction uids" do
      allow_any_instance_of(TransactionValidator).to receive(:validate)
      t1 = Transaction.new; t1.validate; t1.save
      t2 = Transaction.new; t2.validate; t2.save
      get '/api/transactions.json'
      expect(JSON.parse(last_response.body)).to eq([{'uid' => t1.uid}, {'uid' => t2.uid}])
    end
  end

  describe 'GET count' do
    it "should return the number of transactions in the database" do
      allow_any_instance_of(TransactionValidator).to receive(:validate)
      t1 = Transaction.new; t1.validate; t1.save
      t2 = Transaction.new; t2.validate; t2.save

      get '/api/transactions/count.json'
      expect(last_response.body).to eq(Transaction.count.to_s)
    end
  end

  describe "GET /api/transactions/:uid.json" do
    it "should retrieve the transaction in JSON format" do
      prev_transaction_uid = Transaction.new.calculate_uid('fake_transaction')
      input = Input.new(output_transaction: prev_transaction_uid, output_index: 1, script: Script.new(['xyz']))
      output = Output.new(value: 1, script: Script.new(['ZYX']))
      transaction = Transaction.new(inputs: [input], outputs: [output])
      allow_any_instance_of(TransactionValidator).to receive(:validate)
      transaction.validate
      transaction.save

      get "/api/transactions/#{transaction.uid}.json"
      result = JSON.parse(last_response.body)
      expect(result['uid']).to eq(transaction.uid)
      expect(result['inputs']).to eq([{"outputTransaction"=>"c62448673f37ee2e0a0653df70c75c2cf697ee7f", "outputIndex"=>1, "script"=>bytes_to_hex("xyz").upcase, "scriptHex"=>"0378797a"}])
      expect(result['outputs']).to eq([{"outputType"=>1, "value"=>1, "root"=>nil, "asset"=>nil, "script"=>bytes_to_hex("ZYX").upcase, "scriptHex"=>"035a5958"}])
      expect(result['raw']).to eq(bytes_to_hex(transaction.serialize))
    end
  end

  describe "POST" do
    def transaction_post_and_fetch(params)
      post '/api/transactions.json', params.to_json
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
        allow_any_instance_of(TransactionValidator).to receive(:validate)
      end

      it "should return the transaction" do
        post '/api/transactions.json', {}.to_json
        transaction = Transaction.last
        expect(last_response.body).to eq({ uid: transaction.uid, inputs: [], outputs: [], raw: '00000000' }.to_json)
      end
      it "should create an empty transaction record" do
        t = transaction_post_and_fetch({})
        expect(t.inputs).to eq([])
        expect(t.outputs).to eq([])
      end
      it "should create a transaction with a value output" do
        t = transaction_post_and_fetch(outputs: [{ value: 100, script: Script.new([:op_dup]).humanize }])
        expect(t.inputs).to eq([])
        expect(t.outputs.length).to eq(1)
        output = t.outputs[0]
        expect(output.value).to eq(100)
        expect(output.output_type).to eq(Output::VALUE)
        expect(output.asset).to be_nil
        expect(output.script).to eq([:op_dup])
      end
      it "should create a transaction with a SHA256 asset output" do
        asset = sha256('something')
        t = transaction_post_and_fetch(outputs: [{ outputType: 'SHA256', asset: bytes_to_hex(asset), script: Script.new([:op_verify]).humanize }])
        expect(t.inputs).to eq([])
        expect(t.outputs.length).to eq(1)
        output = t.outputs[0]
        expect(output.value).to be_nil
        expect(output.output_type).to eq(Output::SHA256)
        expect(output.asset).to eq(asset)
        expect(output.script).to eq([:op_verify])
      end
      it "should create a transaction with an RMD160 asset output" do
        asset = rmd160('something')
        t = transaction_post_and_fetch(outputs: [{ outputType: 'RMD160', asset: bytes_to_hex(asset), script: Script.new([:op_verify]).humanize }])
        expect(t.inputs).to eq([])
        expect(t.outputs.length).to eq(1)
        output = t.outputs[0]
        expect(output.value).to be_nil
        expect(output.output_type).to eq(Output::RMD160)
        expect(output.asset).to eq(asset)
        expect(output.script).to eq([:op_verify])
      end
      it "should create a transaction with an RMD160 root asset output" do
        root = rmd160('root')
        t = transaction_post_and_fetch(outputs: [{ outputType: 'RMD160-ROOT', root: bytes_to_hex(root), script: Script.new([:op_verify]).humanize }])
        expect(t.inputs).to eq([])
        expect(t.outputs.length).to eq(1)
        output = t.outputs[0]
        expect(output.value).to be_nil
        expect(output.output_type).to eq(Output::RMD160_ROOT)
        expect(output.root).to eq(root)
        expect(output.asset).to eq(root)
        expect(output.script).to eq([:op_verify])
      end
      it "should create a transaction with an RMD160 head asset output" do
        root = rmd160('v1')
        head = rmd160('v2')
        t = transaction_post_and_fetch(outputs: [{ outputType: 'RMD160-HEAD', root: bytes_to_hex(root), asset: bytes_to_hex(head), script: Script.new([:op_verify]).humanize }])
        expect(t.inputs).to eq([])
        expect(t.outputs.length).to eq(1)
        output = t.outputs[0]
        expect(output.value).to be_nil
        expect(output.output_type).to eq(Output::RMD160_HEAD)
        expect(output.root).to eq(root)
        expect(output.asset).to eq(head)
        expect(output.script).to eq([:op_verify])
      end
      it "should create a transaction with an input" do
        prev_transaction_uid = Transaction.new.calculate_uid('fake_content')
        t = transaction_post_and_fetch(inputs: [{ outputTransaction: bytes_to_hex(prev_transaction_uid), outputIndex: 1, script: Script.new(['XYZPDQ']).humanize }])
        expect(t.inputs.length).to eq(1)
        input = t.inputs[0]
        expect(input.output_transaction).to eq(prev_transaction_uid)
        expect(input.output_index).to eq(1)
        expect(input.script).to eq(['XYZPDQ'])
        expect(t.outputs).to eq([])
      end
      it "should create a transaction with multiple inputs and outputs" do
        uid1 = Transaction.new.calculate_uid('fake_content')
        uid2 = Transaction.new.calculate_uid('more_fake_content')
        script1 = Script.new(['test1'])
        script2 = Script.new(['test2'])
        script3 = Script.new(['test3'])
        script4 = Script.new(['test4'])
        asset = sha256('something')

        params = {
          inputs: [
            { outputTransaction: bytes_to_hex(uid1), outputIndex: 10, script: script1.humanize },
            { outputTransaction: bytes_to_hex(uid2), outputIndex: 3,  script: script2.humanize }
          ],
          outputs: [
            # weird things happen if :value is not nil'd here -- the :value => 12 from
            # the subsequent hash somehow gets moved to this one when params are parsed
            { value: nil, outputType: 'SHA256', asset: bytes_to_hex(asset), script: script3.humanize },
            { value: 12, script: script4.humanize }
          ]
        }

        t = transaction_post_and_fetch(params)

        expect(t.inputs.length).to eq(2)
        expect(t.outputs.length).to eq(2)
        expect(bytes_to_hex(t.inputs[0].serialize)).to eq(bytes_to_hex(uid1) + '000a' + bytes_to_hex(script1.serialize))
        expect(bytes_to_hex(t.inputs[1].serialize)).to eq(bytes_to_hex(uid2) + '0003' + bytes_to_hex(script2.serialize))
        expect(bytes_to_hex(t.outputs[0].serialize)).to eq(hex8(Output::SHA256) + bytes_to_hex(asset) + bytes_to_hex(script3.serialize))
        expect(bytes_to_hex(t.outputs[1].serialize)).to eq(hex8(12) + bytes_to_hex(script4.serialize))
      end
    end

    context "with invalid params" do
      it "should return the error information" do
        allow_any_instance_of(TransactionValidator).to receive(:validate).and_raise(Input::MissingScript)
        post '/api/transactions.json', {}.to_json
        expect(last_response.status).to eq(400)
        expect(JSON.parse(last_response.body)['error']).to eq('Input::MissingScript')
      end
    end

  end
end

