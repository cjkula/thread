require 'conversions'

class Output
  include MongoMapper::EmbeddedDocument
  include Conversions

  key :asset_type, Integer
  key :value, Integer
  key :asset, Binary
  key :root, Binary
  key :spent_by_transaction_uid, String
  key :script
  attr_accessor :transaction_uid

  attr_accessible :asset_type, :value, :asset, :root, :script, :spent_by_transaction_uid

  embedded_in :transaction

  class MissingAssetType < StandardError; end
  class InvalidAssetType < StandardError; end
  class AssetInValueTransaction < StandardError; end
  class ValueInAssetTransaction < StandardError; end
  class MissingValue < StandardError; end
  class InvalidValue < StandardError; end
  class MissingAsset < StandardError; end
  class InvalidAsset < StandardError; end
  class MissingAssetRoot < StandardError; end
  class InvalidAssetRoot < StandardError; end
  class UnsupportedAssetType < StandardError; end
  class InvalidAssetLength < StandardError; end
  class MissingScript < StandardError; end

  VALUE_ASSET_TYPE  = 1
  ASSET_MASK        = 0x80000000
  VALUE_UPPER_BOUND = ASSET_MASK - 1
  SHA256_ASSET_TYPE = ASSET_MASK | 0x00
  RMD160_ASSET_TYPE = ASSET_MASK | 0x01
  RMD160_ROOT_TYPE  = ASSET_MASK | 0x02
  RMD160_LEAF_TYPE  = ASSET_MASK | 0x03

  def initialize(args = {})
    super
    self.asset_type = VALUE_ASSET_TYPE if value && !asset_type
    case asset_type
    when RMD160_ROOT_TYPE
      self.root ||= asset # assign with either
      self.asset ||= root
    end
  end

  def serialize
    raise MissingScript unless script

    if value
      raise MissingValue unless asset_type == VALUE_ASSET_TYPE
      serialized = ''
    elsif asset
      serialized = asset.to_s
      case asset_type
      when SHA256_ASSET_TYPE
        asset_length = 32
      when RMD160_ASSET_TYPE, RMD160_ROOT_TYPE
        asset_length = 20
      when RMD160_LEAF_TYPE
        asset_length = 20
        raise MissingAssetRoot unless root
        raise InvalidAssetRoot unless root.length == asset_length
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

    serialize_value_or_type(value || asset_type) + serialized + script.serialize
  end

  def serialize_value_or_type(value_or_type)
    hex_to_bytes(hex8(value_or_type))
  end

  def deserialize(data)
    value_or_type = bytes_to_i(data[0..3])
    raise InvalidAssetType if value_or_type == 0

    if value_or_type <= VALUE_UPPER_BOUND
      self.asset_type = VALUE_ASSET_TYPE
      script_offset = 4
      self.value = value_or_type
      self.asset = nil
    else
      root_length = 0
      case (self.asset_type = value_or_type)
      when SHA256_ASSET_TYPE
        asset_length = 32
      when RMD160_ASSET_TYPE
        has_root = false
        asset_length = 20
      when RMD160_ROOT_TYPE
        root_length = 20
        asset_length = 0
      when RMD160_LEAF_TYPE
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
    self.script.deserialize(data[script_offset..-1]) # returns string remaining
  end

  def validate
    if asset_type == VALUE_ASSET_TYPE
      raise MissingValue unless value
      raise AssetInValueTransaction if asset
      raise InvalidValue unless value.is_a?(Integer) && value > 0
    else
      raise MissingAsset unless asset
      raise ValueInAssetTransaction if value
      root_length = nil
      case asset_type
      when SHA256_ASSET_TYPE
        asset_length = 32
      when RMD160_ASSET_TYPE
        asset_length = 20
      when RMD160_ROOT_TYPE
        raise RootAssetMismatch unless root == asset
        root_length = asset_length = 20
      when RMD160_LEAF_TYPE
        raise LeafAssetRootMatch unless root != asset
        root_length = asset_length = 20
      when nil
        raise MissingAssetType
      else
        raise UnsupportedAssetType
      end
      raise InvalidAsset unless asset.to_s.length == asset_length
      raise InvalidRoot if root_length && (root.to_s.length == root_length)
    end
    raise MissingScript unless script
    script.validate
  end

end
