# frozen_string_literal: true

class AddCreatedViaToIncomingEmail < ActiveRecord::Migration[6.0]
  def change
    add_column :incoming_emails, :created_via, :integer, null: true
  end
end
