require 'conversions'

class Script < Array
  include Conversions

  attr_reader :vm

  class InvalidSerialInput < StandardError; end
  class ScriptLengthError < StandardError; end
  class InvalidScriptData < StandardError; end

  OP_CODES = {
    op_dup:            0x76,
    op_equal:          0x87,
    op_verify:         0x69,
    op_equalverify:    0x88,
    op_add:            0x93,
    op_hash160:        0xa9,
    op_checksig:       0xac,
    op_checksigverify: 0xad
  }
  CODE_OPS = OP_CODES.invert

  def run(vm)
    @vm = vm
    begin
      each { |step| exec(step) }
      vm.valid?
    rescue VirtualMachine::ExecutionError
      false
    end
  end

  def exec(step)
    if OP_CODES.has_key?(step)
      vm.send(step)
    else
      vm.push(step)
    end
  end

  def serialize(include_length = true)
    output = map { |step| step_to_bytes(step) }.join('')
    len = output.size
    raise ScriptLengthError unless len < 65536
    include_length ? hex_to_bytes(hex4(len)) + output : output
  end

  def deserialize(input)
    clear # replace any existing script

    # length of the script is stored in hex in leading 2 bytes
    len = bytes_to_hex(input[0..1]).to_i(16) + 2
    str = input[2...len]
    while str.size > 0
      code = str[0].ord
      str = str[1..-1]
      if code > 0 && code <= 75
        self << str[0...code]
        str = str[code..-1]
      else
        op = CODE_OPS[code] || raise(InvalidSerialInput)
        self << op
      end
    end

    len # return the number of characters used
  end

  def humanize
    map { |step| step_to_human_readable(step) }.join(' ')
  end

  def step_to_human_readable(data)
    if (OP_CODES.has_key?(data))
      data.to_s.upcase
    else
      bytes_to_hex(data).upcase
    end
  end

  def self.import_human_readable(string)
    Script.new string.split(/\s+/).map { |s| import_step(s) }
  end

  def self.import_step(string)
    op = string.downcase.to_sym
    OP_CODES.has_key?(op) ? op : hex_to_bytes(string)
  end

  def step_to_bytes(data)
    if (op = OP_CODES[data])
      op.chr
    else
      str = data.to_s
      len = str.length
      raise InvalidStringLength if len == 0 or len > 75
      len.chr + str
    end
  end

  def validate

  end

end
