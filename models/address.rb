require 'openssl'
require 'conversions'

class Address
  include Conversions

  attr_accessor :private_key, :public_key

  NETWORK_ID = 0 # bitcoin address

  def initialize(args = {})
    @private_key = args[:private_key]
    @public_key = args[:public_key]
  end

  def curve
    'secp256k1'
  end

  def group
    @group ||= OpenSSL::PKey::EC::Group.new(curve)
  end

  def generate
    key = OpenSSL::PKey::EC.new(curve)
    key.generate_key
    @private_key = hex(key.private_key)
    @public_key = hex(key.public_key.to_bn)
    self
  end

  def public_key_hash
    pk_hash(hex_to_bytes(public_key))
  end

  def public_address
    pk_hash_address(hex_to_bytes(public_key), NETWORK_ID)
  end

  def build_openssl_key(public_key, private_key = nil)
    OpenSSL::PKey::EC.new(group).tap do |key|
      key.public_key = OpenSSL::PKey::EC::Point.new(group, OpenSSL::BN.new(public_key, 16))
      key.private_key = OpenSSL::BN.new(private_key, 16) if private_key
    end
  end

  def sign(message)
    build_openssl_key(public_key, private_key).dsa_sign_asn1(message)
  end

  def verify(message, signature)
    build_openssl_key(public_key, private_key).dsa_verify_asn1(message, signature)
  end

end
