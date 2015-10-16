require 'spec_helper'

describe Block do

  it "has a parent block" do
    fake_uid = Digest::SHA256.base64digest('fake_uid')
    expect(Block.new(parent_uid: fake_uid).parent_uid).to eq(fake_uid)
  end

  it "contains transactions" do
    block = Block.new
    transaction = Transaction.new
    block.transactions << transaction
    expect(block.transactions).to include(transaction)
  end

  describe "#serialize_transactions" do
    it "should concatenate each serialized transaction" do
      block = Block.new
      block.transactions << (transaction1 = Transaction.new) << (transaction2 = Transaction.new)
      allow(transaction1).to receive(:serialize).and_return('00000001')
      allow(transaction2).to receive(:serialize).and_return('00000002')
      expect(block.serialize_transactions).to eq('0000000100000002')
    end
  end

  describe "#transaction_root" do
    it "should hash the block of transactions" do
      block = Block.new
      allow(block).to receive(:serialize_transactions).and_return('12345678')
      expect(block.transaction_root).to eq(Digest::SHA256.digest('12345678'))
    end
  end

end
