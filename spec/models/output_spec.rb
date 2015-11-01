require 'spec_helper'
require 'digest'
require 'conversions'
include Conversions

describe Output do

  describe "::all" do
    before do
      allow_any_instance_of(TransactionValidator).to receive(:validate).and_return(nil)
    end
    it "should return the containing transaction_uid as an attribute of each output" do
      tx = Transaction.new(inputs: [], outputs: [ Output.new(output_type: Output::VALUE, value: 100, script: Script.new(['value'])) ])
      tx.validate; tx.save
      result = Output.all
      expect(result.size).to eq(1)
      expect(result[0].transaction_uid).to eq(tx.uid)
    end
  end

  describe "::where" do
    before do
      allow_any_instance_of(TransactionValidator).to receive(:validate).and_return(nil)
    end
    it "should filter by addresses in the output script" do
      address1, address2 = Address.new.generate.public_address, Address.new.generate.public_address
      tx1 = Transaction.new(inputs: [], outputs: [ Output.new(output_type: Output::VALUE, value: 100, script: Script.new([BSON::Binary.new(address1)])) ]); tx1.validate; tx1.save
      tx2 = Transaction.new(inputs: [], outputs: [ Output.new(output_type: Output::VALUE, value: 100, script: Script.new([BSON::Binary.new(address2)])) ]); tx2.validate; tx2.save
      result = Output.where(addresses: [bytes_to_base58(address2)])
      expect(result.size).to eq(1)
      expect(result[0].transaction_uid).to eq(tx2.uid)
    end
    it "should filter by output_type and multiple output types" do
      tx1 = Transaction.new(inputs: [], outputs: [
        Output.new(output_type: Output::VALUE, value: 100, script: Script.new(['value'])),
        Output.new(output_type: Output::SHA256, asset: sha256('1'), script: Script.new(['sha256-1'])),
        Output.new(output_type: Output::SHA256, asset: sha256('2'), script: Script.new(['sha256-2']))
      ]);
      tx2 = Transaction.new(inputs: [], outputs: [
        Output.new(output_type: Output::HASH160_ROOT, root: hash160('3'), script: Script.new(['hash160-root'])),
        Output.new(output_type: Output::HASH160_HEAD, root: hash160('4'), asset: hash160('5'), script: Script.new(['hash160-head'])),
        Output.new(output_type: Output::IDENTITY_ROOT, script: Script.new(['identity-root'])),
        Output.new(output_type: Output::IDENTITY_HEAD, root: hash160('fake'), script: Script.new(['identity-head']))
      ]);
      tx1.validate; tx1.save; tx2.validate; tx2.save
      expect(Output.where(output_type: Output::VALUE).count).to eq(1)
      expect(Output.where(output_type: Output::VALUE)[0].value).to eq(100)
      expect(Output.where(output_type: Output::SHA256).count).to eq(2)
      expect(Output.where(output_type: [Output::SHA256, Output::VALUE]).count).to eq(3)
    end
  end

  describe "::identities" do
    before do
      allow_any_instance_of(TransactionValidator).to receive(:validate).and_return(nil)
    end
    it "should only return identity outputs" do
      tx1 = Transaction.new(inputs: [], outputs: [ Output.new(output_type: Output::VALUE, value: 100, script: Script.new(['value'])) ])
      tx2 = Transaction.new(inputs: [], outputs: [ Output.new(output_type: Output::IDENTITY_ROOT, script: Script.new(['identity-root'])) ])
      tx3 = Transaction.new(inputs: [], outputs: [ Output.new(output_type: Output::IDENTITY_HEAD, root: hash160('fake'), script: Script.new(['identity-head'])) ])
      tx1.validate; tx1.save; tx2.validate; tx2.save; tx3.validate; tx3.save
      expect(Output.identities.count).to eq(2)
    end
    it "should return the currently encumbered identity outputs" do
      root_script = Script.new(['identity-root'])
      root_uid = hash160(root_script.serialize)
      tx1 = Transaction.new(inputs: [], outputs: [ Output.new(output_type: Output::IDENTITY_ROOT, script: root_script) ])
      tx2 = Transaction.new(inputs: [], outputs: [ Output.new(output_type: Output::IDENTITY_HEAD, root: root_uid, script: Script.new(['identity-head'])) ])
      tx3 = Transaction.new(inputs: [], outputs: [ Output.new(output_type: Output::IDENTITY_ROOT, script: Script.new) ])
      tx1.validate; tx1.save; tx2.validate; tx2.save; tx3.validate; tx3.save
      tx1.released_outputs = [tx2.uid]
      tx1.save
      expect(Output.identities.count).to eq(2)
      expect(Output.identities.map(&:script)).not_to include(root_script)
    end
  end

  describe "::identity" do
    before do
      allow_any_instance_of(TransactionValidator).to receive(:validate).and_return(nil)
    end
    it "should find an identity root by uid" do
      root_script = Script.new(['identity-root'])
      root_uid = hash160(root_script.serialize)
      tx = Transaction.new(inputs: [], outputs: [ Output.new(output_type: Output::IDENTITY_ROOT, script: root_script) ])
      tx.validate; tx.save
      expect(Output.identity(root_uid).transaction_uid).to eq(tx.uid)
    end
    it "should find an identity head by root uid" do
      root_script = Script.new(['id1'])
      root_uid = hash160(root_script.serialize)
      tx1 = Transaction.new(inputs: [], outputs: [ Output.new(output_type: Output::IDENTITY_ROOT, script: root_script) ]); tx1.validate; tx1.save
      tx2 = Transaction.new(inputs: [], outputs: [ Output.new(output_type: Output::IDENTITY_HEAD, root: root_uid, script: Script.new(['id2'])) ]); tx2.validate; tx2.save
      tx1.released_outputs = [tx2.uid]; tx1.save
      tx3 = Transaction.new(inputs: [], outputs: [ Output.new(output_type: Output::IDENTITY_HEAD, root: root_uid, script: Script.new(['id3'])) ]); tx3.validate; tx3.save
      tx2.released_outputs = [tx3.uid]; tx2.save
      expect(Output.identity(root_uid).transaction_uid).to eq(tx3.uid)
    end
  end

  it "defaults to a value asset type if value provided" do
    output = Output.new(value: 1)
    expect(output.output_type).to eq(Output::VALUE)
    expect(output.value).to eq(1)
    expect(output.asset).to be_nil
  end
  it "can take a sha256 asset" do
    asset = Digest::SHA256.digest('document')
    output = Output.new(output_type: Output::SHA256, asset: asset)
    expect(output.output_type).to eq(Output::SHA256)
    expect(output.value).to be_nil
    expect(output.asset).to eq(asset)
    expect(output.root).to be_nil
  end
  it "can take an rmd160 asset" do
    asset = Digest::RMD160.digest('document')
    output = Output.new(output_type: Output::RMD160, asset: asset)
    expect(output.output_type).to eq(Output::RMD160)
    expect(output.value).to be_nil
    expect(output.asset).to eq(asset)
    expect(output.root).to be_nil
  end
  it "can take an rmd160 root asset" do
    root = Digest::RMD160.digest('document')
    output = Output.new(output_type: Output::RMD160_ROOT, asset: root)
    expect(output.output_type).to eq(Output::RMD160_ROOT)
    expect(output.value).to be_nil
    expect(output.asset).to eq(root)
    expect(output.root).to eq(root)
  end
  it "can initialize an rmd160 root with the root param" do
    root = Digest::RMD160.digest('document')
    output = Output.new(output_type: Output::RMD160_ROOT, root: root)
    expect(output.output_type).to eq(Output::RMD160_ROOT)
    expect(output.value).to be_nil
    expect(output.asset).to eq(root)
    expect(output.root).to eq(root)
  end
  it "can take an rmd160 head asset" do
    root = Digest::RMD160.digest('v1')
    head = Digest::RMD160.digest('v2')
    output = Output.new(output_type: Output::RMD160_HEAD, asset: head, root: root)
    expect(output.output_type).to eq(Output::RMD160_HEAD)
    expect(output.value).to be_nil
    expect(output.asset).to eq(head)
    expect(output.root).to eq(root)
  end
  it "can have a script" do
    script = Script.new
    expect(Output.new(script: script).script).to eq(script)
  end

  describe "identity" do
    describe "root" do
      it "derives its root id from a hash of the encumbering script" do
        script = Script.new(['12345'])
        output = Output.new(output_type: Output::IDENTITY_ROOT, script: script)
        expect(output.root).to eq(hash160(script.serialize))
        expect(output.asset).to be_nil
      end
    end
    describe "head" do
      it "derives its root id from a hash of the root identity plus the new encumbering script" do
        identity_root = hash160(Script.new(['12345']).serialize)
        head_script = Script.new(['abcde'])
        output = Output.new(output_type: Output::IDENTITY_HEAD, root: identity_root, script: head_script)
        expect(output.root).to eq(identity_root)
        expect(output.asset).to eq(hash160(identity_root + head_script.serialize))
      end
    end
  end

  describe "endorsed root" do
    it "has a root hash id and a script which includes the endorsing identity root" do
      doc_root = rmd160('document')
      identity_root = hash160(Script.new(['12345']).serialize)
      script = Script.new([identity_root])
      output = Output.new(output_type: Output::RMD160_ROOT, root: doc_root, script: script)
      expect(output.root).to eq(doc_root)
      expect(output.asset).to eq(doc_root)
    end
  end

  describe "#validate" do
    before do
      @script = Script.new
      allow_any_instance_of(Script).to receive(:validate)
    end
    it "validates a value" do
      expect { Output.new(value: 12.5, script: @script).validate }.not_to raise_error
    end
    it "validates an asset" do
      expect { Output.new(output_type: Output::SHA256,  asset: sha256('1'),  script: @script).validate }.not_to raise_error
      expect { Output.new(output_type: Output::RMD160,  asset: rmd160('2'),  script: @script).validate }.not_to raise_error
      expect { Output.new(output_type: Output::HASH160, asset: hash160('3'), script: @script).validate }.not_to raise_error
    end
    it "validates an asset root" do
      expect { Output.new(output_type: Output::SHA256_ROOT,  root: sha256('1'),  script: @script).validate }.not_to raise_error
      expect { Output.new(output_type: Output::RMD160_ROOT,  root: rmd160('2'),  script: @script).validate }.not_to raise_error
      expect { Output.new(output_type: Output::HASH160_ROOT, root: hash160('3'), script: @script).validate }.not_to raise_error
    end
    it "validates an asset head" do
      expect { Output.new(output_type: Output::SHA256_HEAD,  root: sha256('1'),  asset: sha256('2'),  script: @script).validate }.not_to raise_error
      expect { Output.new(output_type: Output::RMD160_HEAD,  root: rmd160('1'),  asset: rmd160('2'),  script: @script).validate }.not_to raise_error
      expect { Output.new(output_type: Output::HASH160_HEAD, root: hash160('1'), asset: hash160('2'), script: @script).validate }.not_to raise_error
    end
    it "validates an identity root" do
      expect { Output.new(output_type: Output::IDENTITY_ROOT, script: @script).validate }.not_to raise_error
    end
    it "validates an identity head" do
      expect { Output.new(output_type: Output::IDENTITY_HEAD, root: hash160('abcdef'), script: @script).validate }.not_to raise_error
    end
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
      output = Output.new(output_type: Output::SHA256, asset: asset, script: script)
      allow(script).to receive(:serialize).and_return(hex_to_bytes('0000')) # code for empty script
      expect(bytes_to_hex(output.serialize)).to eq('80000000' + bytes_to_hex(asset) + '0000')
    end
    it "should serialize an RMD160 asset output" do
      asset = Digest::RMD160.digest('document')
      script = Script.new
      output = Output.new(output_type: Output::RMD160, asset: asset, script: script)
      allow(script).to receive(:serialize).and_return(hex_to_bytes('0000'))
      expect(bytes_to_hex(output.serialize)).to eq('80000010' + bytes_to_hex(asset) + '0000')
    end
    it "should serialize an RMD160 root output" do
      root = Digest::RMD160.digest('doc')
      script = Script.new
      output = Output.new(output_type: Output::RMD160_ROOT, root: root, script: script)
      allow(script).to receive(:serialize).and_return(hex_to_bytes('0000'))
      expect(bytes_to_hex(output.serialize)).to eq('80000011' + bytes_to_hex(root) + '0000')
    end
    it "should serialize an RMD160 head output" do
      root = Digest::RMD160.digest('v1')
      head = Digest::RMD160.digest('v2')
      script = Script.new
      output = Output.new(output_type: Output::RMD160_HEAD, root: root, asset: head, script: script)
      allow(script).to receive(:serialize).and_return(hex_to_bytes('0000'))
      expect(bytes_to_hex(output.serialize)).to eq('80000012' + bytes_to_hex(root) + bytes_to_hex(head) + '0000')
    end
    it "should serialize an identity root" do
      script = Script.new(['12345'])
      output = Output.new(output_type: Output::IDENTITY_ROOT, script: script)
      expect(bytes_to_hex(output.serialize)).to eq('ffffffff' + bytes_to_hex(script.serialize))
    end
    it "should serialize an identity head" do
      script = Script.new(['12345'])
      output = Output.new(output_type: Output::IDENTITY_ROOT, script: script)
      expect(bytes_to_hex(output.serialize)).to eq('ffffffff' + bytes_to_hex(script.serialize))
    end
    it "should raise an error if the SHA256 data is not the correct length" do
      output = Output.new(output_type: Output::SHA256, asset: Digest::SHA256.base64digest('document')[0..7], script: Script.new)
      expect { output.serialize }.to raise_error(Output::InvalidAsset)
    end
    it "should raise an error if the asset type is not specified" do
      output = Output.new(output_type: nil, asset: Digest::SHA256.base64digest('document'), script: Script.new)
      expect { output.serialize }.to raise_error(Output::MissingAssetType)
    end
    it "should raise an error if the asset type is not supported" do
      output = Output.new(output_type: -12345, asset: Digest::SHA256.base64digest('document'), script: Script.new)
      expect { output.serialize }.to raise_error(Output::UnsupportedAssetType)
    end
    it "should raise an error if there is no script" do
      output = Output.new(output_type: Output::SHA256, asset: Digest::SHA256.base64digest('document'), script: nil)
      expect { output.serialize }.to raise_error(Output::MissingScript)
    end
  end

  describe "#deserialize" do
    it "should deserialize a value" do
      output = Output.new
      output.deserialize(hex_to_bytes('00000021' + '000276'))
      expect(output.value).to eq(33)
      expect(output.asset).to be_nil
      expect(output.output_type).to eq(Output::VALUE)
      expect(output.script[0]).to eq(:op_dup)
    end
    it "should deserialize a SHA256 asset" do
      output = Output.new
      asset = Digest::SHA256.digest('asset')
      output.deserialize(hex_to_bytes('80000000') + asset + hex_to_bytes('000302fafa'))
      expect(output.value).to be_nil
      expect(output.asset).to eq(asset)
      expect(output.output_type).to eq(Output::SHA256)
      expect(output.script).to eq([hex_to_bytes('fafa')])
    end
    it "should deserialize an RMD160 asset" do
      output = Output.new
      asset = Digest::RMD160.digest('asset')
      output.deserialize(hex_to_bytes('80000010') + asset + hex_to_bytes('0000'))
      expect(output.value).to be_nil
      expect(output.asset).to eq(asset)
      expect(output.output_type).to eq(Output::RMD160)
    end
    it "should deserialize an RMD160 root asset" do
      output = Output.new
      root = Digest::RMD160.digest('root')
      output.deserialize(hex_to_bytes('80000011') + root + hex_to_bytes('0000'))
      expect(output.value).to be_nil
      expect(output.asset).to eq(root)
      expect(output.root).to eq(root)
      expect(output.output_type).to eq(Output::RMD160_ROOT)
    end
    it "should deserialize an RMD160 head asset" do
      output = Output.new
      root = Digest::RMD160.digest('v1')
      head = Digest::RMD160.digest('v2')
      output.deserialize(hex_to_bytes('80000012') + root + head + hex_to_bytes('0000'))
      expect(output.value).to be_nil
      expect(output.asset).to eq(head)
      expect(output.root).to eq(root)
      expect(output.output_type).to eq(Output::RMD160_HEAD)
    end
    it "should deserialize an identity root" do
      output = Output.new
      script = Script.new(['abc'])
      serialized_script = script.serialize
      output.deserialize(hex_to_bytes('ffffffff' + bytes_to_hex(serialized_script)))
      expect(output.output_type).to eq(Output::IDENTITY_ROOT)
      expect(output.root).to eq(hash160(serialized_script))
      expect(output.script).to eq(['abc'])
      expect(output.value).to be_nil
      expect(output.asset).to be_nil
    end
    it "should deserialize an identity head" do
      output = Output.new
      root_id = hash160(Script.new(['root']).serialize)
      head_script = Script.new(['head'])
      serialized_script = head_script.serialize
      output.deserialize(hex_to_bytes('fffffffe' + bytes_to_hex(root_id + serialized_script)))
      expect(output.output_type).to eq(Output::IDENTITY_HEAD)
      expect(output.root).to eq(root_id)
      expect(output.asset).to eq(hash160(root_id + serialized_script))
      expect(output.script).to eq(['head'])
      expect(output.value).to be_nil
    end
    it "should raise an unsupported asset type error if asset type is not recognized" do
      expect { Output.new.deserialize(hex_to_bytes('f00012340000')) }.to raise_error(Output::UnsupportedAssetType)
    end
    it "should raise an invalid asset type error if asset type equals 0" do
      expect { Output.new.deserialize(hex_to_bytes('000000000000')) }.to raise_error(Output::InvalidAssetType)
    end
    it "should be able to reconstruct a serialized object" do
      asset = Digest::SHA256.digest('document')
      original = Output.new(output_type: Output::SHA256, asset: asset, script: Script.new([:op_dup]))
      reconstructed = Output.new
      reconstructed.deserialize(original.serialize)
      expect(reconstructed.output_type).to eq(Output::SHA256)
      expect(reconstructed.asset).to eq(asset)
      expect(reconstructed.script).to eq([:op_dup])
    end
  end

end
