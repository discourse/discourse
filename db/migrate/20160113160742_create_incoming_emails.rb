# frozen_string_literal: true

class CreateIncomingEmails < ActiveRecord::Migration[4.2]
  def change
    create_table :incoming_emails do |t|
      t.integer :user_id
      t.integer :topic_id
      t.integer :post_id

      t.text :raw
      t.text :error

      t.text :message_id
      t.text :from_address
      t.text :to_addresses
      t.text :cc_addresses
      t.text :subject

      t.timestamps null: false
    end

    add_index :incoming_emails, :created_at
    add_index :incoming_emails, :message_id
    add_index :incoming_emails, :error
  end
end
