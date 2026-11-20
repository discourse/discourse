# frozen_string_literal: true

class CreateDsaNotices < ActiveRecord::Migration[8.0]
  def change
    create_table :dsa_notices do |t|
      t.bigint :post_id
      t.text :content_url, null: false
      t.text :explanation, null: false
      t.string :name
      t.string :email
      t.datetime :receipt_sent_at
      t.datetime :created_at, null: false
    end

    add_index :dsa_notices, :post_id, unique: true
  end
end
