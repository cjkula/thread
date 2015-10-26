require 'conversions'

class Input
  include Conversions

  attr_accessor :transaction_uid, :output_index, :script

  class MissingUTXO < StandardError; end
  class InvalidUTXO < StandardError; end
  class MissingOutputIndex < StandardError; end
  class InvalidOutputIndex < StandardError; end
  class MissingScript < StandardError; end

  def initialize(args = {})
    @transaction_uid = args[:transaction_uid]
    @output_index = args[:output_index]
    @script = args[:script]
  end

  def serialize
    raise MissingUTXO unless transaction_uid
    raise MissingOutputIndex unless output_index
    raise MissingScript unless script
    transaction_uid + hex_to_bytes(hex4(output_index)) + script.serialize
  end

  def deserialize(data)
    self.transaction_uid = data[0..19]
    self.output_index = bytes_to_hex(data[20..21]).to_i(16)
    self.script = Script.new
    self.script.deserialize(data[22..-1]) # returns remaining characters
  end

  def validate
    raise MissingUTXO unless transaction_uid
    raise InvalidUTXO unless transaction_uid.length == 20
    raise MissingOutputIndex unless output_index
    raise InvalidOutputIndex unless output_index.is_a?(Integer) && output_index >= 0
    raise MissingScript unless script
    script.validate
  end

end
