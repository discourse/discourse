# frozen_string_literal: true

class AddRejectionMessageToIncomingEmail < ActiveRecord::Migration[4.2]
  def change
    add_column :incoming_emails, :rejection_message, :text
  end
end
