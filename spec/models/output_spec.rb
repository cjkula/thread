require 'spec_helper'
require 'digest'
require 'conversions'

describe Output do
  include Conversions

  it "defaults to a value asset type if value provided" do
    output = Output.new(value: 1)
    expect(output.asset_type).to eq(Output::VALUE_ASSET_TYPE)
    expect(output.value).to eq(1)
    expect(output.asset).to be_nil
  end
  it "can take a sha256 asset" do
    asset = Digest::SHA256.digest('document')
    output = Output.new(asset_type: Output::SHA256_ASSET_TYPE, asset: asset)
    expect(output.asset_type).to eq(Output::SHA256_ASSET_TYPE)
    expect(output.value).to be_nil
    expect(output.asset).to eq(asset)
    expect(output.root).to be_nil
  end
  it "can take an rmd160 asset" do
    asset = Digest::RMD160.digest('document')
    output = Output.new(asset_type: Output::RMD160_ASSET_TYPE, asset: asset)
    expect(output.asset_type).to eq(Output::RMD160_ASSET_TYPE)
    expect(output.value).to be_nil
    expect(output.asset).to eq(asset)
    expect(output.root).to be_nil
  end
  it "can take an rmd160 root asset" do
    root = Digest::RMD160.digest('document')
    output = Output.new(asset_type: Output::RMD160_ROOT_TYPE, asset: root)
    expect(output.asset_type).to eq(Output::RMD160_ROOT_TYPE)
    expect(output.value).to be_nil
    expect(output.asset).to eq(root)
    expect(output.root).to eq(root)
  end
  it "can initialize an rmd160 root with the root param" do
    root = Digest::RMD160.digest('document')
    output = Output.new(asset_type: Output::RMD160_ROOT_TYPE, root: root)
    expect(output.asset_type).to eq(Output::RMD160_ROOT_TYPE)
    expect(output.value).to be_nil
    expect(output.asset).to eq(root)
    expect(output.root).to eq(root)
  end
  it "can take an rmd160 leaf asset" do
    root = Digest::RMD160.digest('v1')
    leaf = Digest::RMD160.digest('v2')
    output = Output.new(asset_type: Output::RMD160_LEAF_TYPE, asset: leaf, root: root)
    expect(output.asset_type).to eq(Output::RMD160_LEAF_TYPE)
    expect(output.value).to be_nil
    expect(output.asset).to eq(leaf)
    expect(output.root).to eq(root)
  end
  it "can have a script" do
    script = Script.new
    expect(Output.new(script: script).script).to eq(script)
  end

  describe "#serialize" do
    it "should serialize a value output" do
      script = Script.new
      output = Output.new(value: 16, script: script)
      allow(script).to receive(:serialize).and_return(hex_to_bytes('0000')) # code for empty script / stubbing just in case
      expect(bytes_to_hex(output.serialize)).to eq('00000010' + '0000')
    end
    it "should serialize a SHA256 asset output" do
      asset = Digest::SHA256.digest('document')
      script = Script.new
      output = Output.new(asset_type: Output::SHA256_ASSET_TYPE, asset: asset, script: script)
      allow(script).to receive(:serialize).and_return(hex_to_bytes('0000')) # code for empty script
      expect(bytes_to_hex(output.serialize)).to eq('80000000' + bytes_to_hex(asset) + '0000')
    end
    it "should serialize an RMD160 asset output" do
      asset = Digest::RMD160.digest('document')
      script = Script.new
      output = Output.new(asset_type: Output::RMD160_ASSET_TYPE, asset: asset, script: script)
      allow(script).to receive(:serialize).and_return(hex_to_bytes('0000'))
      expect(bytes_to_hex(output.serialize)).to eq('80000001' + bytes_to_hex(asset) + '0000')
    end
    it "should serialize an RMD160 root output" do
      root = Digest::RMD160.digest('doc')
      script = Script.new
      output = Output.new(asset_type: Output::RMD160_ROOT_TYPE, root: root, script: script)
      allow(script).to receive(:serialize).and_return(hex_to_bytes('0000'))
      expect(bytes_to_hex(output.serialize)).to eq('80000002' + bytes_to_hex(root) + '0000')
    end
    it "should serialize an RMD160 leaf output" do
      root = Digest::RMD160.digest('v1')
      leaf = Digest::RMD160.digest('v2')
      script = Script.new
      output = Output.new(asset_type: Output::RMD160_LEAF_TYPE, root: root, asset: leaf, script: script)
      allow(script).to receive(:serialize).and_return(hex_to_bytes('0000'))
      expect(bytes_to_hex(output.serialize)).to eq('80000003' + bytes_to_hex(root) + bytes_to_hex(leaf) + '0000')
    end
    it "should raise an error if the SHA256 data is not the correct length" do
      output = Output.new(asset_type: Output::SHA256_ASSET_TYPE, asset: Digest::SHA256.base64digest('document')[0..7], script: Script.new)
      expect { output.serialize }.to raise_error(Output::InvalidAsset)
    end
    it "should raise an error if the asset type is not specified" do
      output = Output.new(asset_type: nil, asset: Digest::SHA256.base64digest('document'), script: Script.new)
      expect { output.serialize }.to raise_error(Output::MissingAssetType)
    end
    it "should raise an error if the asset type is not supported" do
      output = Output.new(asset_type: -12345, asset: Digest::SHA256.base64digest('document'), script: Script.new)
      expect { output.serialize }.to raise_error(Output::UnsupportedAssetType)
    end
    it "should raise an error if there is no script" do
      output = Output.new(asset_type: Output::SHA256_ASSET_TYPE, asset: Digest::SHA256.base64digest('document'), script: nil)
      expect { output.serialize }.to raise_error(Output::MissingScript)
    end
  end

  describe "#deserialize" do
    it "should deserialize a value" do
      output = Output.new
      output.deserialize(hex_to_bytes('00000021' + '000276'))
      expect(output.value).to eq(33)
      expect(output.asset).to be_nil
      expect(output.asset_type).to eq(Output::VALUE_ASSET_TYPE)
      expect(output.script[0]).to eq(:op_dup)
    end
    it "should deserialize a SHA256 asset" do
      output = Output.new
      asset = Digest::SHA256.digest('asset')
      output.deserialize(hex_to_bytes('80000000') + asset + hex_to_bytes('000302fafa'))
      expect(output.value).to be_nil
      expect(output.asset).to eq(asset)
      expect(output.asset_type).to eq(Output::SHA256_ASSET_TYPE)
      expect(output.script).to eq([hex_to_bytes('fafa')])
    end
    it "should deserialize an RMD160 asset" do
      output = Output.new
      asset = Digest::RMD160.digest('asset')
      output.deserialize(hex_to_bytes('80000001') + asset + hex_to_bytes('0000'))
      expect(output.value).to be_nil
      expect(output.asset).to eq(asset)
      expect(output.asset_type).to eq(Output::RMD160_ASSET_TYPE)
    end
    it "should deserialize an RMD160 root asset" do
      output = Output.new
      root = Digest::RMD160.digest('root')
      output.deserialize(hex_to_bytes('80000002') + root + hex_to_bytes('0000'))
      expect(output.value).to be_nil
      expect(output.asset).to eq(root)
      expect(output.root).to eq(root)
      expect(output.asset_type).to eq(Output::RMD160_ROOT_TYPE)
    end
    it "should deserialize an RMD160 leaf asset" do
      output = Output.new
      root = Digest::RMD160.digest('v1')
      leaf = Digest::RMD160.digest('v2')
      output.deserialize(hex_to_bytes('80000003') + root + leaf + hex_to_bytes('0000'))
      expect(output.value).to be_nil
      expect(output.asset).to eq(leaf)
      expect(output.root).to eq(root)
      expect(output.asset_type).to eq(Output::RMD160_LEAF_TYPE)
    end
    it "should raise an unsupported asset type error if asset type is not recognized" do
      expect { Output.new.deserialize(hex_to_bytes('f00012340000')) }.to raise_error(Output::UnsupportedAssetType)
    end
    it "should raise an invalid asset type error if asset type equals 0" do
      expect { Output.new.deserialize(hex_to_bytes('000000000000')) }.to raise_error(Output::InvalidAssetType)
    end
    it "should be able to reconstruct a serialized object" do
      asset = Digest::SHA256.digest('document')
      original = Output.new(asset_type: Output::SHA256_ASSET_TYPE, asset: asset, script: Script.new([:op_dup]))
      reconstructed = Output.new
      reconstructed.deserialize(original.serialize)
      expect(reconstructed.asset_type).to eq(Output::SHA256_ASSET_TYPE)
      expect(reconstructed.asset).to eq(asset)
      expect(reconstructed.script).to eq([:op_dup])
    end
  end

end
