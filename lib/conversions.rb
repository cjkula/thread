require 'digest'

module Conversions
  class FieldOverflow < StandardError; end
  class VersionOverflow < StandardError; end

  #################
  ######### INTEGER
  #################

  def hex_to_i(hex)
    hex.to_i(16)
  end

  def bytes_to_i(string)
    hex_to_i(bytes_to_hex(string))
  end

  #################
  ##### HEXADECIMAL
  #################

  def hex(integer)
    integer.to_s(16)
  end

  # convert integers to fixed-length hexadecimal strings
  def hex_bigendian(integer, length)
    hex = hex(integer)
    raise StringOverflow if hex.length > length
    hex.rjust(length, '0')
  end

  12.times do |i|
    define_method("hex#{ i + 1 }") do |integer|
      hex_bigendian(integer, i + 1)
    end
  end

  def hex_to_bytes(hex)
    [hex].pack('H*')
  end

  def bytes_to_hex(bytes)
    bytes.unpack('H*')[0]
  end

  #################
  ######### HASHING
  #################

  def sha256(document)
    Digest::SHA256.digest(document)
  end

  def rmd160(document)
    Digest::RMD160.digest(document)
  end

  def hash160(document)
    rmd160(sha256(document))
  end

  def pk_checksum(hash)
    sha256(sha256(hash))[0..3]
  end

  def pk_hash(public_key)
    hash160(public_key)
  end

  def pk_hash_address(public_key, network_id)
    hash = network_id.chr + hash160(public_key)
    hash + pk_checksum(hash)
  end

  #################
  ######### BASE-58
  #################

  def encode_base58(hex)
    leading_zero_bytes = (hex.match(/^([0]+)/) ? $1 : '').size / 2
    ("1"*leading_zero_bytes) + int_to_base58( hex.to_i(16) )
  end

  def int_to_base58(int_val, leading_zero_bytes=0)
    alpha = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
    base58_val, base = '', alpha.size
    while int_val > 0
      int_val, remainder = int_val.divmod(base)
      base58_val = alpha[remainder] + base58_val
    end
    base58_val
  end

end
