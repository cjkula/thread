require 'conversions'

class Output
  include Conversions

  attr_accessor :asset_type, :value, :asset, :script

  class MissingAssetType < StandardError; end
  class MissingValue < StandardError; end
  class MissingAsset < StandardError; end
  class InvalidAssetType < StandardError; end
  class UnsupportedAssetType < StandardError; end
  class InvalidAssetLength < StandardError; end
  class MissingScript < StandardError; end

  VALUE_ASSET_TYPE = 1
  VALUE_UPPER_BOUND = 0x7fffffff
  SHA256_ASSET_TYPE = 0xffffffff

  def initialize(args = {})
    @value = args[:value]
    @asset = args[:asset]
    @asset_type = args[:asset_type] || (@value ? VALUE_ASSET_TYPE : nil)
    @script = args[:script]
  end

  def serialize
    raise MissingScript unless script
    case asset_type
    when VALUE_ASSET_TYPE
      raise MissingValue unless value
      serialize_value_or_type(value) + script.serialize
    when SHA256_ASSET_TYPE
      raise MissingAsset unless asset
      raise InvalidAssetLength unless asset.length == 32 # length of a SHA256 hash
      serialize_value_or_type(asset_type) + asset + script.serialize
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

end
