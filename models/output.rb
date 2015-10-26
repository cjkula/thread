require 'conversions'

class Output
  include MongoMapper::EmbeddedDocument
  include Conversions

  key :asset_type, Integer
  key :value, Integer
  key :asset, Binary
  key :spent_by_transaction_uid, String
  key :script
  attr_accessor :transaction_uid

  attr_accessible :asset_type, :value, :asset, :script, :spent_by_transaction_uid

  embedded_in :transaction

  class MissingAssetType < StandardError; end
  class InvalidAssetType < StandardError; end
  class AssetInValueTransaction < StandardError; end
  class ValueInAssetTransaction < StandardError; end
  class MissingValue < StandardError; end
  class InvalidValue < StandardError; end
  class MissingAsset < StandardError; end
  class InvalidAsset < StandardError; end
  class UnsupportedAssetType < StandardError; end
  class InvalidAssetLength < StandardError; end
  class MissingScript < StandardError; end

  VALUE_ASSET_TYPE = 1
  VALUE_UPPER_BOUND = 0x7fffffff
  SHA256_ASSET_TYPE = 0xffffffff

  def initialize(args = {})
    super
    self.asset_type = VALUE_ASSET_TYPE if value && !asset_type
  end

  def serialize
    raise MissingScript unless script
    case asset_type
    when VALUE_ASSET_TYPE
      raise MissingValue unless value
      serialize_value_or_type(value) + script.serialize
    when SHA256_ASSET_TYPE
      raise MissingAsset unless asset
      raise InvalidAsset unless asset.length == 32 # length of a SHA256 hash
      serialize_value_or_type(asset_type) + asset.to_s + script.serialize
    when nil
      raise MissingAssetType
    else
      raise UnsupportedAssetType
    end
  end

  def serialize_value_or_type(value_or_type)
    hex_to_bytes(hex8(value_or_type))
  end

  def deserialize(data)
    value_or_type = bytes_to_i(data[0..3])
    raise InvalidAssetType if value_or_type == 0

    if value_or_type > VALUE_UPPER_BOUND
      raise UnsupportedAssetType unless value_or_type == SHA256_ASSET_TYPE
      self.asset_type = value_or_type
      self.value = nil
      self.asset = data[4..35]
      script_offset = 36
    else
      self.asset_type = VALUE_ASSET_TYPE
      self.value = value_or_type
      self.asset = nil
      script_offset = 4
    end

    self.script = Script.new
    self.script.deserialize(data[script_offset..-1]) # returns string remaining
  end

  def validate
    case asset_type
    when VALUE_ASSET_TYPE
      raise MissingValue unless value
      raise InvalidValue unless value.is_a?(Integer) && value > 0
      raise AssetInValueTransaction if asset
    when SHA256_ASSET_TYPE
      ValueInAssetTransaction
      raise MissingAsset unless asset
      raise InvalidAsset unless asset.to_s.length == 32
      raise ValueInAssetTransaction if value
    when nil
      raise MissingAssetType
    else
      raise UnsupportedAssetType
    end
    raise MissingScript unless script
    script.validate
  end

end
