# frozen_string_literal: true

class CreateDsaNotices < ActiveRecord::Migration[8.0]
  def change
    create_table :dsa_notices do |t|
      t.uuid :submission_id, null: false
      t.string :reference, null: false
      t.bigint :post_id, null: false
      t.text :content_url, null: false
      t.text :explanation, null: false
      t.boolean :anonymous, null: false, default: false
      t.string :name
      t.string :email
      t.boolean :declaration, null: false
      t.datetime :group_notified_at
      t.datetime :receipt_sent_at
      t.timestamps null: false
    end

    add_index :dsa_notices, :submission_id, unique: true
    add_index :dsa_notices, :reference, unique: true
    add_index :dsa_notices, :post_id, unique: true
  end
end
