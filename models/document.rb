require 'conversions'

class Document
  include MongoMapper::Document
  include Conversions

  class Duplicate < StandardError; end
  class MissingUID < StandardError; end

  key :uid, String
  key :headers, String
  key :body, Binary

  attr_accessible :uid, :content, :headers, :body

  validates_uniqueness_of :uid

  def initialize(content)
    self.content = content
  end

  def content=(c)
    end_headers = c.index("\n\n")
    body_start = end_headers ? end_headers + 2 : 0
    self.headers = c[0...body_start]
    self.body = c[body_start..-1]
  end

  def content
    headers + body.to_s
  end

  def headers=(headers)
    calculate_uid(headers + body.to_s) if (headers && body)
    super
  end

  def body=(body)
    calculate_uid(headers + body.to_s) if (headers && body)
    super
  end

  def calculate_uid(content)
    self.uid = bytes_to_hex(hash160(content))
  end

  def content_type
    matches = /^Content-Type: (.*)$/.match(headers)
    matches ? matches[1] : nil
  end

  def size
    body ? body.length : 0
  end

end
