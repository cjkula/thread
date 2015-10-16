require 'spec_helper'

describe VirtualMachine do
  def execute(op, stack = [])
    vm = VirtualMachine.new
    (vm.stack = stack).tap { vm.send(op) }
  end

  it "has a stack" do
    expect(VirtualMachine.new.stack).to eq([])
  end

  it "accepts a transaction" do
    transaction = Transaction.new
    expect(VirtualMachine.new(transaction: transaction).transaction).to eq(transaction)
  end

  describe "#valid?" do
    it "evaluates true if the top item on the stack is truthy" do
      vm = VirtualMachine.new
      vm.stack = [true]
      expect(vm.valid?).to eq(true)
    end
    it "evaluates false if the top item on the stack is falsey (including zero)" do
      vm = VirtualMachine.new
      [ [], [nil], [false], [0], [0.0] ].each do |stack|
        vm.stack = stack
        expect(vm.valid?).to eq(false)
      end
    end
  end

  describe "#op_equal" do
    it "outputs true if the top two stack items are equal" do
      expect(execute(:op_equal, [:thing, :thing])).to eq([true])
      expect(execute(:op_equal, [false, false])).to eq([true])
    end
    it "outputs false if the top two stack items are unequal" do
      expect(execute(:op_equal, [true, :other])).to eq([false])
    end
    it "raises an underflow error if stack has less than two items" do
      expect { execute(:op_equal) }.to raise_error(VirtualMachine::StackUnderflow)
      expect { execute(:op_equal, [1]) }.to raise_error(VirtualMachine::StackUnderflow)
    end
  end

  describe "#op_verify" do
    it "clears the top stack item if truthy" do
      expect(execute(:op_verify, [:truthy_thing])).to eq([])
    end
    it "raises a verification error if the top stack item is missing or falsey" do
      expect { execute(:op_verify) }.to raise_error(VirtualMachine::VerificationFailure)
      expect { execute(:op_verify, [0]) }.to raise_error(VirtualMachine::VerificationFailure)
      expect { execute(:op_verify, [false]) }.to raise_error(VirtualMachine::VerificationFailure)
    end
  end

  describe "#op_equalverify" do
    it "clears the top two stack items if equal" do
      expect(execute(:op_equalverify, [:thing, :thing])).to eq([])
      expect(execute(:op_equalverify, [false, false])).to eq([])
    end
    it "returns false if the top two stack items are unequal" do
      expect { execute(:op_equalverify, [true, :other]) }.to raise_error(VirtualMachine::VerificationFailure)
    end
    it "raises an underflow error if stack has less than two items" do
      expect { execute(:op_equalverify) }.to raise_error(VirtualMachine::StackUnderflow)
      expect { execute(:op_equalverify, [1]) }.to raise_error(VirtualMachine::StackUnderflow)
    end
  end

  describe "#op_dup" do
    it "copies the top item on the stack" do
      expect(execute(:op_dup, [:TOKEN])).to eq([:TOKEN, :TOKEN])
    end
    it "raises an underflow error if stack is empty" do
      expect{ execute(:op_dup) }.to raise_error(VirtualMachine::StackUnderflow)
    end
  end

  describe "#op_hash160" do
    it "hashes the top item on the stack" do
      public_key = '0123456789abcdef'
      hash = bytes_to_hex(Digest::RMD160.digest(Digest::SHA256.digest(hex_to_bytes(public_key))))
      expect(execute(:op_hash160, [public_key])).to eq([hash])
    end
    it "raises an underflow error if stack is empty" do
      expect { execute(:op_hash160) }.to raise_error(VirtualMachine::StackUnderflow)
    end
  end

  describe "#op_add" do
    it "adds the top two items on the stack" do
      expect(execute(:op_add, [13, 111])).to eq([124])
    end
    it "raises an underflow error if stack has less than two items" do
      expect { execute(:op_add) }.to raise_error(VirtualMachine::StackUnderflow)
      expect { execute(:op_add, [1]) }.to raise_error(VirtualMachine::StackUnderflow)
    end
  end

  describe "#op_checksig" do
    it "returns true if key validates the signature of the unreleased output" do
      vm = VirtualMachine.new(transaction: Transaction.new, output_index: 0)
      allow(vm.transaction).to receive(:uid).and_return('faux_uid')
      address = Address.new.generate
      sig = address.sign('faux_uid')
      vm.stack = [sig, address.public_key]
      vm.op_checksig
      expect(vm.stack).to eq([true])
    end
    it "returns false if key fails to validate the signature of the unreleased output" do
      vm = VirtualMachine.new(transaction: Transaction.new, output_index: 0)
      allow(vm.transaction).to receive(:uid).and_return('faux_uid')
      vm.stack = [Address.new.generate.sign('faux_uid'), Address.new.generate.public_key]
      vm.op_checksig
      expect(vm.stack).to eq([false])
    end
  end

  describe "#op_checksigverify" do
    it "clear the signature and public key from the stack if key validates the signature of the unreleased output" do
      vm = VirtualMachine.new(transaction: Transaction.new, output_index: 0)
      allow(vm.transaction).to receive(:uid).and_return('faux_uid')
      address = Address.new.generate
      sig = address.sign('faux_uid')
      vm.stack = [sig, address.public_key]
      vm.op_checksigverify
      expect(vm.stack).to eq([])
    end
    it "raise a verification error if key fails to validate the signature of the unreleased output" do
      vm = VirtualMachine.new(transaction: Transaction.new, output_index: 0)
      allow(vm.transaction).to receive(:uid).and_return('faux_uid')
      vm.stack = [Address.new.generate.sign('faux_uid'), Address.new.generate.public_key]
      expect { vm.op_checksigverify }.to raise_error(VirtualMachine::VerificationFailure)
    end
  end

  describe "#push" do
    it "places data on the stack" do
      vm = VirtualMachine.new
      vm.push(:something)
      expect(vm.stack).to eq([:something])
    end
  end

end
