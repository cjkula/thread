require 'spec_helper'
require 'conversions'

describe Input do
  include Conversions

  it "references a transaction uid, output index, and script" do
    fake_transaction_uid = Digest::SHA256.base64digest('fake_id')
    script = Script.new
    input = Input.new(transaction_uid: fake_transaction_uid, output_index: 0, script: script)
    expect(input.transaction_uid).to eq(fake_transaction_uid)
    expect(input.output_index).to eq(0)
    expect(input.script).to eq(script)
  end

  describe "#serialize" do
    it "should serialize a well-formed input" do
      script = Script.new
      allow(script).to receive(:serialize).and_return('fake')
      fake_transaction_uid = Digest::SHA256.digest('fake_id')
      input = Input.new(transaction_uid: fake_transaction_uid, output_index: 2, script: script)
      expect(input.serialize).to eq(fake_transaction_uid + hex_to_bytes('0002') + 'fake')
    end
    it "should raise an error if the transaction_uid is not specified" do
      input = Input.new(output_index: 1, script: Script.new)
      expect { input.serialize }.to raise_error(Input::MissingUTXO)
    end
    it "should raise an error if the output_index is not specified" do
      input = Input.new(transaction_uid: Digest::SHA256.base64digest('fake_id'), script: Script.new)
      expect { input.serialize }.to raise_error(Input::MissingOutputIndex)
    end
    it "should raise an error if there is no script" do
      input = Input.new(transaction_uid: Digest::SHA256.base64digest('fake_id'), output_index: 1)
      expect { input.serialize }.to raise_error(Input::MissingScript)
    end
  end

  describe "#deserialize" do
    it "should accept well-formed input" do
      fake_transaction_uid = rmd160('fake_id')
      input = Input.new
      input.deserialize(fake_transaction_uid + hex_to_bytes('000a000169'))
      expect(input.transaction_uid).to eq(fake_transaction_uid)
      expect(input.output_index).to eq(10)
      expect(input.script).to eq([:op_verify])
    end
  end

end
