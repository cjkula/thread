require 'spec_helper'
require 'conversions'
require 'json'

describe Transaction do
  include Conversions

  describe "when valid" do
    before(:each) do
      @transaction = Transaction.new
      allow_any_instance_of(TransactionValidator).to receive(:validate).and_return(nil)
    end

    it "can be saved and retrieved" do
      transaction = Transaction.new
      transaction.validate
      transaction.save
      uid = transaction.uid
      transaction_fetch = Transaction.where(uid: uid).first
      expect(transaction_fetch.uid).to eq(uid)
    end

    it "can retrieve a transaction by output asset" do
      asset = sha256('data')
      output = Output.new(output_type: Output::SHA256, asset: BSON::Binary.new(asset), script: Script.new)
      transaction = Transaction.new(outputs: [output])
      transaction.validate
      transaction.save
      uid = transaction.uid
      transaction_fetch = Transaction.where("outputs.asset" => BSON::Binary.new(asset)).first
      expect(transaction_fetch.uid).to eq(uid)
    end

    it "can serialize a transaction to the db and restore it" do
      output = Output.new(value: 14, script: Script.new([:op_verify]))
      transaction = Transaction.new( inputs: [], outputs: [output] )
      hex_transaction = '0000' + '0001' + '0000000e' + '000169'
      transaction.validate
      transaction.save
      expect(bytes_to_hex(transaction.blob.to_s)).to eq(hex_transaction)
      uid = transaction.uid
      restored = Transaction.where(uid: uid).first
      restored.deserialize
      expect(bytes_to_hex(restored.blob.to_s)).to eq(hex_transaction)
      expect(restored.inputs).to eq([])
      expect(restored.outputs.size).to eq(1)
      output = restored.outputs[0]
      expect(output.value).to eq(14)
      expect(output.output_type).to eq(Output::VALUE)
      expect(output.script).to eq([:op_verify])
    end

    describe '#inputs' do
      it "should contain a list of transactions" do
        expect(@transaction.inputs).to eq([])
        inputs = [Input.new, Input.new]
        @transaction.inputs += inputs
        expect(@transaction.inputs).to eq(inputs)
      end
    end

    describe "#validated?" do
      it "should report whether or not the transaction has been validated" do
        expect(@transaction.validated?).to eq(false)
        @transaction.validate
        expect(@transaction.validated?).to eq(true)
      end
    end

    describe "#valid?" do
      it "should raise an error if validity is unknown" do
        expect { @transaction.valid? }.to raise_error(Transaction::NotValidated)
      end
      it "should report a valid state" do
        allow_any_instance_of(TransactionValidator).to receive(:validate)
        @transaction.validate
        expect(@transaction.valid?).to eq(true)
      end
      it "should report an invalid state" do
        allow_any_instance_of(TransactionValidator).to receive(:validate).and_raise(StandardError)
        begin
          @transaction.validate
        rescue StandardError
        end
        expect(@transaction.valid?).to eq(false)
        expect(@transaction.validated?).to eq(true)
      end
    end

    describe "#serialize" do
      it "accepts a transaction with one input and one output" do
        prev_transaction = Transaction.new.calculate_uid('fake_transaction')
        input = Input.new(output_transaction: prev_transaction, output_index: 1, script: Script.new(['xyz']))
        output = Output.new(value: 1, script: Script.new(['ZYX']))
        transaction = Transaction.new(inputs: [input], outputs: [output])
        expect(bytes_to_hex(transaction.serialize)).to eq('0001' + bytes_to_hex(prev_transaction) + '0001' + '000403' + bytes_to_hex('xyz') +
                                                          '0001' + '00000001' + '000403' + bytes_to_hex('ZYX'))
      end
      it "accepts a transaction with multiple inputs and outputs" do
        prev_transaction1 = Transaction.new.calculate_uid('fake_transaction1')
        prev_transaction2 = Transaction.new.calculate_uid('fake_transaction1')
        input1 = Input.new(output_transaction: prev_transaction1, output_index: 1, script: Script.new([hex_to_bytes('1111')]))
        input2 = Input.new(output_transaction: prev_transaction2, output_index: 2, script: Script.new([hex_to_bytes('2222')]))
        output1 = Output.new(value: 10, script: Script.new(['aa']))
        asset2 = Digest::SHA256.digest('asset2')
        output2 = Output.new(output_type: Output::SHA256, asset: asset2, script: Script.new(['zz']))
        transaction = Transaction.new(inputs: [input1, input2], outputs: [output1, output2])
        expect(bytes_to_hex(transaction.serialize)).to eq('0002' + bytes_to_hex(prev_transaction1) + '0001' + '0003021111' +
                                                                   bytes_to_hex(prev_transaction2) + '0002' + '0003022222' +
                                                          '0002' + '0000000a' + '000302' + bytes_to_hex('aa') +
                                                                   '80000000' + bytes_to_hex(asset2) + '000302' + bytes_to_hex('zz'))
      end
      it "accepts a transaction with no inputs" do
        transaction = Transaction.new( inputs: [], outputs: [ Output.new(value: 14, script: Script.new([:op_verify])) ] )
        expect(bytes_to_hex(transaction.serialize)).to eq('0000' + '0001' + '0000000e' + '000169')
      end
    end

    describe "#deserialize" do
      it "reads a transaction with one input and one output" do
        prev_transaction = rmd160('fake_id')
        reconstructed = Transaction.new
        reconstructed.deserialize(hex_to_bytes('0001' + bytes_to_hex(prev_transaction) + '0001' + '000403' + bytes_to_hex('abc') +
                                               '0001' + '00000001' + '000403' + bytes_to_hex('123')))
        expect(reconstructed.inputs.size).to eq(1)
        input = reconstructed.inputs[0]
        expect(input.output_transaction).to eq(prev_transaction)
        expect(input.output_index).to eq(1)
        expect(input.script).to eq(['abc'])
        expect(reconstructed.outputs.size).to eq(1)
        output = reconstructed.outputs[0]
        expect(output.output_type).to eq(Output::VALUE)
        expect(output.value).to eq(1)
        expect(output.script).to eq(['123'])
      end
      it "reads a transaction with multiple inputs and outputs" do
        prev_transaction1 = rmd160('fake_id1')
        prev_transaction2 = rmd160('fake_id2')
        asset2 = Digest::SHA256.digest('asset2')
        reconstructed = Transaction.new
        reconstructed.deserialize(hex_to_bytes('0002' + bytes_to_hex(prev_transaction1) + '0001' + '000504' + bytes_to_hex('1111') +
                                                        bytes_to_hex(prev_transaction2) + '0002' + '000504' + bytes_to_hex('2222') +
                                               '0002' + '0000000a' + '000302' + bytes_to_hex('11') +
                                                        '80000000' + bytes_to_hex(asset2) + '000302' + bytes_to_hex('22')))

        expect(reconstructed.inputs.size).to eq(2)
        input1 = reconstructed.inputs[0]
        expect(input1.output_transaction).to eq(prev_transaction1)
        expect(input1.output_index).to eq(1)
        expect(input1.script).to eq(['1111'])
        input2 = reconstructed.inputs[1]
        expect(input2.output_transaction).to eq(prev_transaction2)
        expect(input2.output_index).to eq(2)
        expect(input2.script).to eq(['2222'])

        expect(reconstructed.outputs.size).to eq(2)
        output1 = reconstructed.outputs[0]
        expect(output1.output_type).to eq(Output::VALUE)
        expect(output1.value).to eq(10)
        expect(output1.asset).to be_nil
        expect(output1.script).to eq(['11'])
        output2 = reconstructed.outputs[1]
        expect(output2.output_type).to eq(Output::SHA256)
        expect(output2.value).to be_nil
        expect(output2.asset).to eq(asset2)
        expect(output2.script).to eq(['22'])
      end
    end
  end

  context "with identities" do
    before do
      allow_any_instance_of(Script).to receive(:validate)
      script1 = Script.new(['testing1'])
      script2 = Script.new(['testing2'])
      @root_uid1 = hash160(script1.serialize)
      @root_uid2 = hash160(script2.serialize)
      @tx1 = Transaction.new( inputs: [], outputs: [Output.new(output_type: Output::IDENTITY_ROOT, script: script1)] ); @tx1.validate; @tx1.save
      @tx2 = Transaction.new( inputs: [], outputs: [Output.new(output_type: Output::IDENTITY_ROOT, script: script2)] ); @tx2.validate; @tx2.save
    end
    it "should create a new identities" do
      expect(Output.identities.count).to eq(2)
      expect(Output.identities.first.transaction_uid).to eq(@tx1.uid)
      expect(Output.identity(@root_uid1).transaction_uid).to eq(@tx1.uid)
    end
    it "should update an identity root in a transaction" do
      update_tx = Transaction.new(
                    inputs: [Input.new(output_transaction: hex_to_bytes(@tx1.uid), output_index: 0, script: Script.new)],
                    outputs: [Output.new(output_type: Output::IDENTITY_HEAD, root: @root_uid1, script: Script.new)]
                  );
      update_tx.validate
      update_tx.publish
      expect(Output.identity(@root_uid1).transaction_uid).to eq(update_tx.uid)
    end
    it "should update an identity head in a transaction" do
      update_tx1 = Transaction.new(
                    inputs: [Input.new(output_transaction: hex_to_bytes(@tx1.uid), output_index: 0, script: Script.new)],
                    outputs: [Output.new(output_type: Output::IDENTITY_HEAD, root: @root_uid1, script: Script.new)]
                  );
      update_tx1.validate; update_tx1.publish
      update_tx2 = Transaction.new(
                    inputs: [Input.new(output_transaction: hex_to_bytes(update_tx1.uid), output_index: 0, script: Script.new)],
                    outputs: [Output.new(output_type: Output::IDENTITY_HEAD, root: @root_uid1, script: Script.new)]
                  );
      update_tx2.validate; update_tx2.publish
      expect(Output.identity(@root_uid1).transaction_uid).to eq(update_tx2.uid)
    end
  end

  context "with endorsed assets" do
    it "should include the endorser root id in the encumbering script" do

    end
  end

end
