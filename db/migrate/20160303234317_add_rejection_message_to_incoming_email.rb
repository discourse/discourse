class AddRejectionMessageToIncomingEmail < ActiveRecord::Migration
  def change
    add_column :incoming_emails, :rejection_message, :text
  end
end
