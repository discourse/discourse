class FixIncomingEmailsIndices < ActiveRecord::Migration[4.2]
  def change
    add_index :incoming_emails, :post_id
  end
end
