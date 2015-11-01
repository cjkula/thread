module Seed

  def self.truncate
    Transaction.destroy_all
    Document.destroy_all
  end

  def self.spool
    truncate
    users = create_user_documents
    identities = create_identities(users)
    create_statuses(identities)
    identities
  end

  def self.create_identities(user_docs)
    user_docs.map do |user_doc|
      address = Address.new.generate
      identity_script = Script.new([BSON::Binary.new(address.public_address)])
      user_script = Script.new([BSON::Binary.new(address.public_address)])
      id_tx = Transaction.new(outputs: [ Output.new(output_type: Output::IDENTITY_ROOT, script: identity_script),
                                         Output.new(output_type: Output::HASH160_ROOT, root: hex_to_bytes(user_doc.uid), script: user_script) ])
      id_tx.validate
      id_tx.save
      address
    end
  end

  def self.create_user_documents
    header = "Content-Type: application/json\n\n"

    user_data = [
      {
        handle: 'JoeBob1',
        fullName: 'Joe Bob Briggs',
        description: 'King of all rewritable media',
        avatar: 'avatars/joebob.jpg'
      },
      {
        handle: 'MaryJane2',
        fullName: 'Mary Jane Paul',
        description: 'Cleaning all the things since 2009',
        avatar: 'avatars/maryjane.jpg'
      }
    ]

    user_data.map { |user| Document.create(header + user.to_json) }
  end

  def self.create_statuses(identities)

  end
end
