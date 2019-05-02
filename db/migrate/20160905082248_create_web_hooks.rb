# frozen_string_literal: true

class CreateWebHooks < ActiveRecord::Migration[4.2]
  def change
    create_table :web_hooks do |t|
      t.string  :payload_url, null: false
      t.integer :content_type, default: 1, null: false
      t.integer :last_delivery_status, default: 1, null: false
      t.integer :status, default: 1, null: false
      t.string  :secret, default: ''
      t.boolean :wildcard_web_hook, default: false, null: false
      t.boolean :verify_certificate, default: true, null: false
      t.boolean :active, default: false, null: false

      t.timestamps null: false
    end
  end
end
