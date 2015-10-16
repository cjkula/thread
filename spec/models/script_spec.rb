require 'spec_helper'
require 'conversions'

describe Script do
  include Conversions

  def run_eval(steps, stack = [])
    vm = VirtualMachine.new
    vm.stack = stack
    Script.new(steps).run(vm)
  end

  it "is a subclass of Array" do
    expect(Script.new).to be_a_kind_of(Array)
  end

  describe "#serialize" do
    it "serializes opcodes" do
      script = Script.new([:op_dup, :op_equal, :op_verify, :op_equalverify, :op_add, :op_hash160])
      expect(bytes_to_hex(script.serialize)).to eq('00067687698893a9')
    end
    it "serializes small data pushes" do
      data1 = 'X'
      data75 = 'n' * 75
      script = '01' + bytes_to_hex(data1) + '4b' + bytes_to_hex(data75) # 0x4b == 75
      expect(bytes_to_hex(Script.new([data1, data75]).serialize)).to eq(hex4(script.size/2) + script)
    end
  end

  describe "#deserialize" do
    it "deserializes opcodes" do
      script = Script.new
      script.deserialize(hex_to_bytes('00067687698893a9'))
      expect(script.to_a).to eq([:op_dup, :op_equal, :op_verify, :op_equalverify, :op_add, :op_hash160])
    end
    it "deserializes small string pushes" do
      script = Script.new
      script.deserialize(hex_to_bytes('000c02abcd080123456789abcdef'))
      expect(script.to_a).to eq([hex_to_bytes('abcd'), hex_to_bytes('0123456789abcdef')])
    end
  end

  describe "#run" do
    it "returns true if the VM evaluates to valid after execution" do
      vm = VirtualMachine.new
      expect(vm).to receive(:valid?).and_return(true)
      expect(Script.new.run(vm)).to eq(true)
    end
    it "returns false if the VM evaluates to not valid after execution" do
      vm = VirtualMachine.new
      expect(vm).to receive(:valid?).and_return(false)
      expect(Script.new.run(vm)).to eq(false)
    end
  end

  describe "validation sequence" do
    context "for a single signature" do
      before do
        @vm = VirtualMachine.new(transaction: Transaction.new, output_index: 0)
        allow(@vm.transaction).to receive(:uid).and_return('faux_uid')
        @owner = Address.new.generate
        @imposter = Address.new.generate
        @script = Script.new([:op_dup, :op_hash160, bytes_to_hex(@owner.public_key_hash), :op_equalverify, :op_checksig])
      end
      it "should validate with correct public key" do
        @vm.stack = [@owner.sign('faux_uid'), @owner.public_key]
        expect(@script.run(@vm)).to eq(true)
      end
      it "should not validate with incorrect public key" do
        @vm.stack = [@imposter.sign('faux_uid'), @imposter.public_key]
        expect(@script.run(@vm)).to eq(false)
      end
      it "should be able to be serialized and deserialized" do
        new_script = Script.new
        new_script.deserialize(@script.serialize)
        expect(new_script).to eq(@script)
      end
    end
  end
end
