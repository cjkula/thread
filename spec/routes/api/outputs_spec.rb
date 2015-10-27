require 'spec_helper'
require 'conversions'
include Conversions

describe "/outputs API" do

  describe 'GET /api/outputs' do
    before do
      allow_any_instance_of(TransactionValidator).to receive(:validate) # disable validation
    end

    it "should return all outputs" do
      t1 = Transaction.new(outputs: [Output.new(value: 1, script: Script.new), Output.new(value: 2, script: Script.new)]); t1.validate; t1.save
      t2 = Transaction.new(outputs: [Output.new(asset_type: Output::SHA256_ASSET_TYPE, asset: sha256('~'), script: Script.new)]); t2.validate; t2.save
      get '/api/outputs.json'
      expect(JSON.parse(last_response.body).length).to eq(3)
    end
    it "should include the uid of the containing transaction" do
      t = Transaction.new(outputs: [Output.new(value: 1, script: Script.new), Output.new(value: 2, script: Script.new)]); t.validate; t.save
      get '/api/outputs.json'
      expect(JSON.parse(last_response.body)[0]['transactionUid']).to eq(t.uid)
    end
    it "should filter outputs with scripts containing a single destination address" do
      address1, address2 = Address.new.generate.public_address, Address.new.generate.public_address
      t1 = Transaction.new(outputs: [Output.new(value: 1, script: Script.new([bytes_to_hex(address1)]))]); t1.validate; t1.save
      t2 = Transaction.new(outputs: [Output.new(value: 1, script: Script.new([bytes_to_hex(address2)]))]); t2.validate; t2.save
      get '/api/outputs.json', addresses: [bytes_to_base58(address1)]
      expect(JSON.parse(last_response.body).length).to eq(1)
      expect(JSON.parse(last_response.body)[0]['transactionUid']).to eq(t1.uid)
      get '/api/outputs.json', addresses: [bytes_to_base58(address2)]
      expect(JSON.parse(last_response.body).length).to eq(1)
      expect(JSON.parse(last_response.body)[0]['transactionUid']).to eq(t2.uid)
    end
    it "should filter outputs with scripts containing multiple destination addresses" do
      address1, address2, address3 = Address.new.generate.public_address, Address.new.generate.public_address, Address.new.generate.public_address
      t1 = Transaction.new(outputs: [Output.new(value: 1, script: Script.new([bytes_to_hex(address1)]))]); t1.validate; t1.save
      t2 = Transaction.new(outputs: [Output.new(value: 1, script: Script.new([bytes_to_hex(address2)]))]); t2.validate; t2.save
      get '/api/outputs.json', addresses: [bytes_to_base58(address1), bytes_to_base58(address2)]
      expect(JSON.parse(last_response.body).length).to eq(2)
    end
  end

  describe 'GET /api/values' do
    before do
      allow_any_instance_of(TransactionValidator).to receive(:validate) # disable validation
    end

    it "should return all values" do
      t1 = Transaction.new(outputs: [Output.new(value: 1, script: Script.new), Output.new(value: 2, script: Script.new)]); t1.validate; t1.save
      t2 = Transaction.new(outputs: [Output.new(value: 3, script: Script.new), Output.new(asset_type: Output::SHA256_ASSET_TYPE, asset: sha256('~'), script: Script.new)]); t2.validate; t2.save
      get '/api/values.json'
      expect(JSON.parse(last_response.body).length).to eq(3)
    end
    it "should not return non-value outputs" do
      t = Transaction.new(outputs: [Output.new(asset_type: Output::SHA256_ASSET_TYPE, asset: sha256('~'), script: Script.new), Output.new(value: 20, script: Script.new)]); t.validate; t.save
      get '/api/values.json'
      expect(JSON.parse(last_response.body).length).to eq(1)
      expect(JSON.parse(last_response.body)[0]['value']).to eq(20)
    end
    it "should filter values with scripts containing a single destination address" do
      address1, address2 = Address.new.generate.public_address, Address.new.generate.public_address
      t1 = Transaction.new(outputs: [Output.new(value: 1, script: Script.new([bytes_to_hex(address1)]))]); t1.validate; t1.save
      t2 = Transaction.new(outputs: [Output.new(value: 1, script: Script.new([bytes_to_hex(address2)]))]); t2.validate; t2.save
      get '/api/values.json', addresses: [bytes_to_base58(address1)]
      expect(JSON.parse(last_response.body).length).to eq(1)
      expect(JSON.parse(last_response.body)[0]['transactionUid']).to eq(t1.uid)
      get '/api/values.json', addresses: [bytes_to_base58(address2)]
      expect(JSON.parse(last_response.body).length).to eq(1)
      expect(JSON.parse(last_response.body)[0]['transactionUid']).to eq(t2.uid)
    end
    it "should filter values with scripts containing multiple destination addresses" do
      address1, address2, address3 = Address.new.generate.public_address, Address.new.generate.public_address, Address.new.generate.public_address
      t1 = Transaction.new(outputs: [Output.new(value: 1, script: Script.new([bytes_to_hex(address1)]))]); t1.validate; t1.save
      t2 = Transaction.new(outputs: [Output.new(value: 1, script: Script.new([bytes_to_hex(address2)]))]); t2.validate; t2.save
      get '/api/values.json', addresses: [bytes_to_base58(address1), bytes_to_base58(address2)]
      expect(JSON.parse(last_response.body).length).to eq(2)
    end
  end

  describe 'GET /api/assets' do
    before do
      allow_any_instance_of(TransactionValidator).to receive(:validate) # disable validation
    end

    it "should return all assets" do
      t1 = Transaction.new(outputs: [Output.new(value: 1, script: Script.new), Output.new(asset_type: Output::SHA256_ASSET_TYPE, asset: sha256('1'), script: Script.new)]); t1.validate; t1.save
      t2 = Transaction.new(outputs: [Output.new(value: 2, script: Script.new), Output.new(asset_type: Output::SHA256_ASSET_TYPE, asset: sha256('2'), script: Script.new)]); t2.validate; t2.save
      get '/api/assets.json'
      expect(JSON.parse(last_response.body).length).to eq(2)
    end
    it "should not return non-asset outputs" do
      asset = sha256('~')
      t = Transaction.new(outputs: [Output.new(asset_type: Output::SHA256_ASSET_TYPE, asset: asset, script: Script.new), Output.new(value: 20, script: Script.new)]); t.validate; t.save
      get '/api/assets.json'
      expect(JSON.parse(last_response.body).length).to eq(1)
      expect(JSON.parse(last_response.body)[0]['asset']).to eq(bytes_to_hex(asset))
    end
    it "should filter assets with scripts containing a single destination address" do
      address1, address2 = Address.new.generate.public_address, Address.new.generate.public_address
      t1 = Transaction.new(outputs: [Output.new(value: 1, script: Script.new), Output.new(asset_type: Output::SHA256_ASSET_TYPE, asset: sha256('1'), script: Script.new([bytes_to_hex(address1)]))]); t1.validate; t1.save
      t2 = Transaction.new(outputs: [Output.new(value: 2, script: Script.new), Output.new(asset_type: Output::SHA256_ASSET_TYPE, asset: sha256('2'), script: Script.new([bytes_to_hex(address2)]))]); t2.validate; t2.save
      get '/api/assets.json', addresses: [bytes_to_base58(address1)]
      expect(JSON.parse(last_response.body).length).to eq(1)
      expect(JSON.parse(last_response.body)[0]['transactionUid']).to eq(t1.uid)
      get '/api/assets.json', addresses: [bytes_to_base58(address2)]
      expect(JSON.parse(last_response.body).length).to eq(1)
      expect(JSON.parse(last_response.body)[0]['transactionUid']).to eq(t2.uid)
    end
    it "should filter assets with scripts containing a single destination address" do
      address1, address2, address3 = Address.new.generate.public_address, Address.new.generate.public_address, Address.new.generate.public_address
      t1 = Transaction.new(outputs: [Output.new(value: 1, script: Script.new), Output.new(asset_type: Output::SHA256_ASSET_TYPE, asset: sha256('1'), script: Script.new([bytes_to_hex(address1)]))]); t1.validate; t1.save
      t2 = Transaction.new(outputs: [Output.new(value: 2, script: Script.new), Output.new(asset_type: Output::SHA256_ASSET_TYPE, asset: sha256('2'), script: Script.new([bytes_to_hex(address2)]))]); t2.validate; t2.save
      t3 = Transaction.new(outputs: [Output.new(value: 3, script: Script.new), Output.new(asset_type: Output::SHA256_ASSET_TYPE, asset: sha256('3'), script: Script.new([bytes_to_hex(address3)]))]); t3.validate; t3.save
      get '/api/assets.json', addresses: [bytes_to_base58(address1), bytes_to_base58(address3)]
      expect(JSON.parse(last_response.body).length).to eq(2)
    end
    it "should retrieve by asset root"
  end

end
