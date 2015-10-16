require 'spec_helper'
require 'conversions'

include Conversions

describe Address do
  describe '::generate' do
    it 'should create a new public/private key pair' do
      address = Address.new.generate
      expect(address.private_key).not_to be_nil
      expect(address.public_key).not_to be_nil
    end
  end

  describe '#public_key_hash' do
    it "should return a hash of the public key" do
      address = Address.new.generate
      hash = Digest::RMD160.digest(Digest::SHA256.digest(hex_to_bytes(address.public_key)))
      expect(address.public_key_hash).to eq(hash)
    end
  end

  describe '#public_address' do
    it "should return a hash of the public key with network and checksum" do
      address = Address.new.generate
      hash = 0.chr + Digest::RMD160.digest(Digest::SHA256.digest(hex_to_bytes(address.public_key)))
      checksum = Digest::SHA256.digest(Digest::SHA256.digest(hash))[0..3]
      expect(address.public_address).to eq(hash + checksum)
    end
  end

  describe '#sign' do
    before do
      @address = Address.new.generate
    end
    it "should return a valid signature of the supplied document" do
      message = 'testing testing 123'
      signature = @address.sign(message)
      group = OpenSSL::PKey::EC::Group.new('secp256k1')
      reconstructed_key = OpenSSL::PKey::EC.new(group)
      bn = OpenSSL::BN.new(@address.public_key, 16)
      reconstructed_key.public_key = OpenSSL::PKey::EC::Point.new(group, bn)
      expect(reconstructed_key.dsa_verify_asn1(message, signature)).to eq(true)
    end
  end

  describe '#verify' do
    context "when the address contains only the public key" do
      before do
        @message = 'Can you hear me now?'
        @originator = Address.new.generate
        @other = Address.new.generate
        @address = Address.new
        @address.public_key = @originator.public_key
      end

      it "should return true if valid" do
        expect(@address.verify(@message, @originator.sign(@message))).to eq(true)
      end

      it "should return false if invalid" do
        expect(@address.verify(@message, @other.sign(@message))).to eq(false)
      end
    end
  end

end
