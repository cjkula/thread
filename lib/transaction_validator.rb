class TransactionValidator

  attr_accessor :transaction

  class MissingOutput < StandardError; end

  def initialize(transaction)
    @transaction = transaction
  end

  def validate
    transaction.inputs.each(&:validate) if transaction.inputs
    raise MissingOutput unless (transaction.outputs && transaction.outputs.size > 0)
    transaction.outputs.each(&:validate)
    nil
  end

end
