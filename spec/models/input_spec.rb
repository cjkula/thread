require 'spec_helper'
require 'conversions'

describe Input do
  include Conversions

  it "references a transaction uid, output index, and script" do
    fake_output_transaction = Digest::SHA256.base64digest('fake_id')
    script = Script.new
    input = Input.new(output_transaction: fake_output_transaction, output_index: 0, script: script)
    expect(input.output_transaction).to eq(fake_output_transaction)
    expect(input.output_index).to eq(0)
    expect(input.script).to eq(script)
  end

  describe "#serialize" do
    it "should serialize a well-formed input" do
      script = Script.new
      allow(script).to receive(:serialize).and_return('fake')
      fake_output_transaction = Digest::SHA256.digest('fake_id')
      input = Input.new(output_transaction: fake_output_transaction, output_index: 2, script: script)
      expect(input.serialize).to eq(fake_output_transaction + hex_to_bytes('0002') + 'fake')
    end
    it "should raise an error if the output_transaction is not specified" do
      input = Input.new(output_index: 1, script: Script.new)
      expect { input.serialize }.to raise_error(Input::MissingUTXO)
    end
    it "should raise an error if the output_index is not specified" do
      input = Input.new(output_transaction: Digest::SHA256.base64digest('fake_id'), script: Script.new)
      expect { input.serialize }.to raise_error(Input::MissingOutputIndex)
    end
    it "should raise an error if there is no script" do
      input = Input.new(output_transaction: Digest::SHA256.base64digest('fake_id'), output_index: 1)
      expect { input.serialize }.to raise_error(Input::MissingScript)
    end
  end

  describe "#deserialize" do
    it "should accept well-formed input" do
      fake_output_transaction = rmd160('fake_id')
      input = Input.new
      input.deserialize(fake_output_transaction + hex_to_bytes('000a000169'))
      expect(input.output_transaction).to eq(fake_output_transaction)
      expect(input.output_index).to eq(10)
      expect(input.script).to eq([:op_verify])
    end
  end

end
