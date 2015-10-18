require 'conversions'
require 'transaction_validator'
require "base64"

class Transaction
  include MongoMapper::Document
  include Conversions

  key :uid, String
  key :blob, Binary
  key :published, Boolean

  attr_accessible :uid, :blob, :published

  attr_accessor :inputs, :outputs

  class Invalid < StandardError; end
  class NotValidated < StandardError; end

  def initialize(args = {})
    @inputs = args[:inputs] || []
    @outputs = args[:outputs] || []
  end

  def save
    raise NotValidated unless validated?
    raise Invalid unless valid?

    bytes = serialize
    self.blob = bytes
    self.uid = bytes_to_hex(calculate_uid(bytes))
    super
  end

  def validate
    TransactionValidator.new(self).validate
    @validated = @valid = true
  rescue StandardError => e
    @valid = false
    @validated = true
    raise e
  end

  def validated?
    !!@validated
  end

  def valid?
    raise NotValidated unless validated?
    !!@valid
  end

  def calculate_uid(bytes)
    rmd160(bytes)
  end

  def serialize
    hex_to_bytes(hex4(inputs.size)  + bytes_to_hex(inputs.map(&:serialize).join('')) +
                 hex4(outputs.size) + bytes_to_hex(outputs.map(&:serialize).join('')))
  end

  def deserialize(data = nil)
    self.inputs = []
    self.outputs = []
    deserialize_outputs(deserialize_inputs(data || blob.to_s))
  end

  def deserialize_inputs(data)
    count = bytes_to_i(data[0..1])
    str = data[2..-1]
    count.times do
      inputs << (input = Input.new)
      str = input.deserialize(str)
    end
    str
  end

  def deserialize_outputs(data)
    count = bytes_to_i(data[0..1])
    str = data[2..-1]
    count.times do
      outputs << (output = Output.new)
      str = output.deserialize(str)
    end
    str
  end

end
