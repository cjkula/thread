require 'conversions'

class Block
  include Conversions

  attr_reader :block_type, :parent_uid, :timestamp, :nonce, :transactions, :block_uid

  GENESIS_BLOCK = 0xA
  STANDARD_BLOCK = 0xB

  def initialize(args = {})
    @block_type = args[:block_type] || STANDARD_BLOCK
    @parent_uid = args[:parent_uid]
    @transactions = args[:transactions] || []
  end

  def serialize_header(set_nonce = nil)
    nonce = set_nonce if set_nonce
    hex1(block_type) + hex9(timestamp) + parent_uid + transaction_root + hex8(nonce)
  end

  def transaction_root
    sha256(serialize_transactions)
  end

  def serialize_transactions
    transactions.map(&:serialize).join('')
  end

end
