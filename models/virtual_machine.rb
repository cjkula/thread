 require 'conversions'

 class VirtualMachine
  include Conversions

  attr_accessor :transaction, :output_index, :stack, :alt_stack

  class ExecutionError < StandardError; end
  class StackUnderflow < ExecutionError; end
  class VerificationFailure < ExecutionError; end
  class InvalidInstruction < ExecutionError; end
  class MissingTransactionInput < ExecutionError; end

  def initialize(args = {})
    @transaction = args[:transaction]
    @output_index = args[:output_index]
    @stack = []
  end

  def truthy(value)
    value == 0 ? false : !!value
  end

  def valid?
    truthy(stack.last)
  end

  def min_stack(height)
    raise StackUnderflow unless stack.size >= height
  end

  def op_dup
    min_stack 1
    stack << stack.last
  end

  def op_equal
    min_stack 2
    stack << (stack.pop == stack.pop)
  end

  def op_verify
    raise VerificationFailure unless valid?
    stack.pop
  end

  def op_equalverify
    op_equal
    op_verify
  end

  def op_add
    min_stack 2
    stack << stack.pop + stack.pop
  end

  def op_hash160
    min_stack 1
    stack << bytes_to_hex(hash160(hex_to_bytes(stack.pop)))
  end

  def op_checksig
    min_stack 2
    raise VirtualMachine::MissingTransactionInput unless transaction && output_index
    stack << Address.new(public_key: stack.pop).verify(transaction.uid, stack.pop)
  end

  def op_checksigverify
    op_checksig
    op_verify
  end

  def push(data)
    stack << data
  end

end
