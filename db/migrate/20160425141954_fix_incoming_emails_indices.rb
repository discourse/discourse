class FixIncomingEmailsIndices < ActiveRecord::Migration
  def change
    add_index :incoming_emails, :post_id
  end
end
