require 'spec_helper'
require 'conversions'
require 'json'

describe Transaction do
  include Conversions

  before do
    @transaction = Transaction.new
  end

  describe "when valid" do
    before(:each) do
      allow_any_instance_of(TransactionValidator).to receive(:validate).and_return(nil)
    end

    it "can be saved and retrieved" do
      transaction = Transaction.new
      transaction.validate
      transaction.save
      uid = transaction.uid
      transaction2 = Transaction.where(uid: uid).first
      expect(transaction2.uid).to eq(uid)
    end

    it "can serialize a transaction to the db and restore it" do
      transaction = Transaction.new( inputs: [], outputs: [ Output.new(value: 14, script: Script.new([:op_verify])) ] )
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
      expect(output.asset_type).to eq(Output::VALUE_ASSET_TYPE)
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
        prev_transaction_uid = Transaction.new.calculate_uid('fake_transaction')
        input = Input.new(transaction_uid: prev_transaction_uid, output_index: 1, script: Script.new(['xyz']))
        output = Output.new(value: 1, script: Script.new(['ZYX']))
        transaction = Transaction.new(inputs: [input], outputs: [output])
        expect(bytes_to_hex(transaction.serialize)).to eq('0001' + bytes_to_hex(prev_transaction_uid) + '0001' + '000403' + bytes_to_hex('xyz') +
                                                          '0001' + '00000001' + '000403' + bytes_to_hex('ZYX'))
      end
      it "accepts a transaction with multiple inputs and outputs" do
        prev_transaction_uid1 = Transaction.new.calculate_uid('fake_transaction1')
        prev_transaction_uid2 = Transaction.new.calculate_uid('fake_transaction1')
        input1 = Input.new(transaction_uid: prev_transaction_uid1, output_index: 1, script: Script.new([hex_to_bytes('1111')]))
        input2 = Input.new(transaction_uid: prev_transaction_uid2, output_index: 2, script: Script.new([hex_to_bytes('2222')]))
        output1 = Output.new(value: 10, script: Script.new(['aa']))
        asset2 = Digest::SHA256.digest('asset2')
        output2 = Output.new(asset_type: Output::SHA256_ASSET_TYPE, asset: asset2, script: Script.new(['zz']))
        transaction = Transaction.new(inputs: [input1, input2], outputs: [output1, output2])
        expect(bytes_to_hex(transaction.serialize)).to eq('0002' + bytes_to_hex(prev_transaction_uid1) + '0001' + '0003021111' +
                                                                   bytes_to_hex(prev_transaction_uid2) + '0002' + '0003022222' +
                                                          '0002' + '0000000a' + '000302' + bytes_to_hex('aa') +
                                                                   'ffffffff' + bytes_to_hex(asset2) + '000302' + bytes_to_hex('zz'))
      end
      it "accepts a transaction with no inputs" do
        transaction = Transaction.new( inputs: [], outputs: [ Output.new(value: 14, script: Script.new([:op_verify])) ] )
        expect(bytes_to_hex(transaction.serialize)).to eq('0000' + '0001' + '0000000e' + '000169')
      end
    end

    describe "#deserialize" do
      it "reads a transaction with one input and one output" do
        prev_transaction_uid = rmd160('fake_id')
        reconstructed = Transaction.new
        reconstructed.deserialize(hex_to_bytes('0001' + bytes_to_hex(prev_transaction_uid) + '0001' + '000403' + bytes_to_hex('abc') +
                                               '0001' + '00000001' + '000403' + bytes_to_hex('123')))
        expect(reconstructed.inputs.size).to eq(1)
        input = reconstructed.inputs[0]
        expect(input.transaction_uid).to eq(prev_transaction_uid)
        expect(input.output_index).to eq(1)
        expect(input.script).to eq(['abc'])
        expect(reconstructed.outputs.size).to eq(1)
        output = reconstructed.outputs[0]
        expect(output.asset_type).to eq(Output::VALUE_ASSET_TYPE)
        expect(output.value).to eq(1)
        expect(output.script).to eq(['123'])
      end
      it "reads a transaction with multiple inputs and outputs" do
        prev_transaction_uid1 = rmd160('fake_id1')
        prev_transaction_uid2 = rmd160('fake_id2')
        asset2 = Digest::SHA256.digest('asset2')
        reconstructed = Transaction.new
        reconstructed.deserialize(hex_to_bytes('0002' + bytes_to_hex(prev_transaction_uid1) + '0001' + '000504' + bytes_to_hex('1111') +
                                                        bytes_to_hex(prev_transaction_uid2) + '0002' + '000504' + bytes_to_hex('2222') +
                                               '0002' + '0000000a' + '000302' + bytes_to_hex('11') +
                                                        'ffffffff' + bytes_to_hex(asset2) + '000302' + bytes_to_hex('22')))

        expect(reconstructed.inputs.size).to eq(2)
        input1 = reconstructed.inputs[0]
        expect(input1.transaction_uid).to eq(prev_transaction_uid1)
        expect(input1.output_index).to eq(1)
        expect(input1.script).to eq(['1111'])
        input2 = reconstructed.inputs[1]
        expect(input2.transaction_uid).to eq(prev_transaction_uid2)
        expect(input2.output_index).to eq(2)
        expect(input2.script).to eq(['2222'])

        expect(reconstructed.outputs.size).to eq(2)
        output1 = reconstructed.outputs[0]
        expect(output1.asset_type).to eq(Output::VALUE_ASSET_TYPE)
        expect(output1.value).to eq(10)
        expect(output1.asset).to be_nil
        expect(output1.script).to eq(['11'])
        output2 = reconstructed.outputs[1]
        expect(output2.asset_type).to eq(Output::SHA256_ASSET_TYPE)
        expect(output2.value).to be_nil
        expect(output2.asset).to eq(asset2)
        expect(output2.script).to eq(['22'])
      end
    end

    it "should represent a transfer of encumbrance" do
      # block = Block.new
      # transaction_1 = Transaction.new
      # transaction_1.outputs << Output.new
      # block.transactions << transaction_1

    end

  end

end
