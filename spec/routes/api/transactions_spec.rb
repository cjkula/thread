require 'spec_helper'
require 'conversions'

include Conversions

describe '/api/transactions' do
  describe 'GET count' do
    it "should return the number of transactions in the database" do
      allow_any_instance_of(TransactionValidator).to receive(:valid?).and_return(true)
      t1 = Transaction.new; t1.validate; t1.save
      t2 = Transaction.new; t2.validate; t2.save

      get '/api/transactions/count'
      expect(last_response.body).to eq(Transaction.count.to_s)
    end
  end

  describe "POST" do
    def transaction_post_and_fetch(params)
      post '/api/transactions', params
      # expect(last_response).to be_ok
      transaction = nil
      # sometimes will fail the first or second time attempted --
      # perhaps need to wait for the DB to finish previous write
      10.times do
        transaction = Transaction.last(uid: last_response.body)
        break if transaction
      end
      transaction.deserialize
      transaction
    end

    before do
      allow_any_instance_of(TransactionValidator).to receive(:valid?).and_return(true)
    end

    it "should return the transaction uid" do
      post '/api/transactions', {}
      transaction = Transaction.last
      expect(last_response.body).to eq(transaction.uid)
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
          # weird things happen if :value is not nil'd here
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
end

