require 'spec_helper'

include Conversions

describe Conversions do
  describe "#bytes_to_hex" do
    it "should convert a byte string into hex" do
      expect(bytes_to_hex('¡olleh')).to eq('c2a16f6c6c6568')
    end
  end
  describe "#hex_to_bytes" do
    it "should convert a string hex representation into the represented byte string" do
      expect(hex_to_bytes('68656c6c6f21')).to eq('hello!')
    end
  end
  describe "#pk_hash" do
    it "applied SHA256 and RIPEMD160" do
      pk_hex = '0450863AD64A87AE8A2FE83C1AF1A8403CB53F53E486D8511DAD8A04887E5B23522CD470243453A299FA9E77237716103ABC11A1DF38855ED6F2EE187E9C582BA6'
      hash = pk_hash(hex_to_bytes(pk_hex))
      expect(bytes_to_hex(hash).upcase).to eq('010966776006953D5567439E5E39F86A0D273BEE')
    end
  end
  describe "#pk_hash_address" do
    it "should convert a bytecode ECDSA public key into its hashed representation" do
      pk_hex = '0450863AD64A87AE8A2FE83C1AF1A8403CB53F53E486D8511DAD8A04887E5B23522CD470243453A299FA9E77237716103ABC11A1DF38855ED6F2EE187E9C582BA6'
      address = pk_hash_address(hex_to_bytes(pk_hex), 0)
      expect(bytes_to_hex(address).upcase).to eq('00010966776006953D5567439E5E39F86A0D273BEED61967F6')
    end
    it "should work for network ids other than zero" do
      pk_hex = '0450863AD64A87AE8A2FE83C1AF1A8403CB53F53E486D8511DAD8A04887E5B23522CD470243453A299FA9E77237716103ABC11A1DF38855ED6F2EE187E9C582BA6'
      address = pk_hash_address(hex_to_bytes(pk_hex), 2)
      hash = hash160(hex_to_bytes(pk_hex))
      checksum = Digest::SHA256.digest(Digest::SHA256.digest(2.chr + hash))[0..3]
      expect(bytes_to_hex(address)).to eq('02' + bytes_to_hex(hash) + bytes_to_hex(checksum))
    end
  end
  describe "#encode_base58" do
    it "should convert a hex value to base58" do
      pk_hash_hex = '00010966776006953D5567439E5E39F86A0D273BEED61967F6'
      expect(encode_base58(pk_hash_hex)).to eq('16UwLL9Risc3QfPqBUvKofHmBQ7wMtjvM')
    end
  end
  describe "#decode_base58" do
    it "should convert a base58 value to hex" do
      pk_hash_hex = '00010966776006953D5567439E5E39F86A0D273BEED61967F6'
      expect(decode_base58('16UwLL9Risc3QfPqBUvKofHmBQ7wMtjvM')).to eq(pk_hash_hex)
    end
  end
end
