require 'conversions'

class Output
  include MongoMapper::EmbeddedDocument
  include Conversions

  key :output_type, Integer
  key :value, Integer
  key :asset, Binary
  key :root, Binary
  key :script
  attr_accessor :transaction_uid, :releasing_transaction

  attr_accessible :output_type, :value, :asset, :root, :script, :releasing_transaction

  embedded_in :transaction

  class OutputError < StandardError; end
  class MissingAssetType                      < OutputError; end
  class InvalidAssetType                      < OutputError; end
  class TypeDoesNotAcceptAsset                < OutputError; end
  class TypeDoesNotAcceptValue                < OutputError; end
  class MissingValue                          < OutputError; end
  class InvalidValue                          < OutputError; end
  class MissingAsset                          < OutputError; end
  class InvalidAsset                          < OutputError; end
  class MissingIdentityRoot                   < OutputError; end
  class MissingRoot                           < OutputError; end
  class InvalidRoot                           < OutputError; end
  class UnsupportedAssetType                  < OutputError; end
  class InvalidAssetLength                    < OutputError; end
  class MissingScript                         < OutputError; end
  class IdentityRootDoesNotMatchScript        < OutputError; end
  class IdentityHeadDoesNotMatchRootAndScript < OutputError; end

  VALUE   = 1
  IDENTITY_ROOT     = 0xFFFFFFFF
  IDENTITY_HEAD     = 0xFFFFFFFE
  ASSET_MASK        = 0x80000000
  VALUE_UPPER_BOUND = ASSET_MASK - 1
  SHA256            = ASSET_MASK | 0x00
  SHA256_ROOT       = ASSET_MASK | 0x01
  SHA256_HEAD       = ASSET_MASK | 0x02
  RMD160            = ASSET_MASK | 0x10
  RMD160_ROOT       = ASSET_MASK | 0x11
  RMD160_HEAD       = ASSET_MASK | 0x12
  HASH160           = ASSET_MASK | 0x20
  HASH160_ROOT      = ASSET_MASK | 0x21
  HASH160_HEAD      = ASSET_MASK | 0x22

  def self.all
    transactions = Transaction.all
    transactions.each(&:deserialize)
    transactions.map do |transaction|
      transaction.outputs.tap do |outputs|
        outputs.each_with_index do |output, index|
          output.transaction_uid = transaction.uid unless transaction.released_outputs[index]
        end
      end.select { |output| output.transaction_uid }
    end.flatten
  end

  def self.where(filter)
    all.tap do |result|
      # check for presense of public address in script matching base58 input
      if (addresses = filter.delete('addresses') || filter.delete(:addresses))
        public_addresses = addresses.map { |a| hex_to_bytes(decode_base58(a)) }
        result.select! do |output|
          (public_addresses & output.script).length > 0
        end
      end

      # check for presense of identities in script
      if (identities = filter.delete('identities') || filter.delete(:identities))
        identities.map! { |a| hex_to_bytes(a) }
        result.select! do |output|
          (identities & output.script).length > 0
        end
      end

      # iterate through each filter key and reduce set
      filter.each_pair do |key, value|
        result.select! do |output|
          actual = output.send(key)
          value.is_a?(Array) ? value.include?(actual) : actual == value
        end
      end
    end
  end

  def self.with(field_name, filter = {})
    where(filter).select(&field_name)
  end

  def self.without(field_name, filter = {})
    where(filter).reject(&field_name)
  end

  def self.identities(filter = {})
    identity_filter = { output_type: [Output::IDENTITY_ROOT, Output::IDENTITY_HEAD] }
    where(identity_filter.merge(filter))
  end

  def self.identity(uid)
    identities.find { |o| o.root == uid }
  end

  def initialize(args = {})
    super
    self.output_type = VALUE if value && !output_type
    case output_type
    when IDENTITY_ROOT
      h = identity_hash
      self.root ||= h
      raise IdentityRootDoesNotMatchScript unless root == h
    when IDENTITY_HEAD
      raise MissingIdentityRoot unless root
      h = identity_hash(root.to_s + script.serialize)
      self.asset ||= h
      raise IdentityHeadDoesNotMatchRootAndScript unless asset == h
    when SHA256_ROOT, RMD160_ROOT, HASH160_ROOT
      self.root ||= asset # assign with either
      self.asset ||= root
    end
  end

  def serialize
    raise MissingScript unless script

    if value
      raise MissingValue unless output_type == VALUE
      serialized = ''
    elsif output_type == IDENTITY_ROOT
      raise TypeDoesNotAcceptAsset if asset
      serialized = ''
    elsif output_type == IDENTITY_HEAD
      serialized = root.to_s
    elsif asset
      serialized = asset.to_s
      case output_type
      when SHA256
        asset_length = 32
      when RMD160, RMD160_ROOT, HASH160_ROOT
        asset_length = 20
      when RMD160_HEAD, HASH160_HEAD
        asset_length = 20
        raise MissingRoot unless root
        raise InvalidRoot unless root.length == asset_length
        serialized = root.to_s + serialized
      when nil
        raise MissingAssetType
      else
        raise UnsupportedAssetType
      end
      raise InvalidAsset unless asset.length == asset_length
    else
      raise MissingAsset
    end

    serialize_value_or_type(value || output_type) + serialized + script.serialize
  end

  def serialize_value_or_type(value_or_type)
    hex_to_bytes(hex8(value_or_type))
  end

  def identity_hash(serialized_script = nil)
    hash160(serialized_script || script.serialize)
  end

  def deserialize(data)
    value_or_type = bytes_to_i(data[0..3])
    raise InvalidAssetType if value_or_type == 0

    if value_or_type <= VALUE_UPPER_BOUND
      self.output_type = VALUE
      script_offset = 4
      self.value = value_or_type
      self.asset = nil
    else
      root_length = 0
      asset_length = 0
      self.output_type = value_or_type
      case output_type
      when IDENTITY_ROOT
        # no root or asset serialized
      when IDENTITY_HEAD
        root_length = 20
      when SHA256
        asset_length = 32
      when RMD160
        has_root = false
        asset_length = 20
      when RMD160_ROOT, HASH160_ROOT
        root_length = 20
        asset_length = 0
      when RMD160_HEAD, HASH160_HEAD, IDENTITY_HEAD
        root_length = 20
        asset_length = 20
      else
        raise UnsupportedAssetType
      end
      self.value = nil
      asset_offset = 4 + root_length
      script_offset = asset_offset + asset_length
      self.root = root_length > 0 ? data[4...asset_offset] : nil
      self.asset = asset_length > 0 ? data[asset_offset...script_offset] : root
    end

    self.script = Script.new
    script_length = self.script.deserialize(data[script_offset..-1])
    script_bytes = data[script_offset, script_length]

    case output_type
    when IDENTITY_ROOT
      self.root = identity_hash(script_bytes)
    when IDENTITY_HEAD
      self.asset = identity_hash(root.to_s + script_bytes)
    end

    data[(script_offset + script_length)..-1] # returns remaining characters
  end

  def validate
    root_length = 0
    asset_length = 0
    if output_type == VALUE
      raise MissingValue unless value
      raise TypeDoesNotAcceptAsset if asset
      raise InvalidValue unless value.is_a?(Integer) && value > 0
    elsif output_type == IDENTITY_ROOT
      raise MissingRoot unless root
      raise TypeDoesNotAcceptAsset if asset
    elsif output_type == IDENTITY_HEAD
      raise MissingRoot unless root
      root_length = 20
    else
      raise MissingAsset unless asset
      raise TypeDoesNotAcceptValue if value
      case output_type
      when SHA256
        asset_length = 32
      when RMD160, HASH160
        asset_length = 20
      when SHA256_ROOT
        raise RootAssetMismatch unless root == asset
        root_length = asset_length = 32
      when SHA256_HEAD
        raise LeafAssetRootMatch unless root != asset
        root_length = asset_length = 32
      when RMD160_ROOT, HASH160_ROOT
        raise RootAssetMismatch unless root == asset
        root_length = asset_length = 20
      when RMD160_HEAD, HASH160_HEAD
        raise LeafAssetRootMatch unless root != asset
        root_length = asset_length = 20
      when nil
        raise MissingAssetType
      else
        raise UnsupportedAssetType
      end
    end

    raise InvalidRoot if (root_length > 0) && (root.to_s.length != root_length)
    raise InvalidAsset if (asset_length > 0) && (asset.to_s.length != asset_length)
    raise MissingScript unless script
    script.validate
  end

end
