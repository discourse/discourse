# frozen_string_literal: true

class AddApiKeyScopes < ActiveRecord::Migration[6.0]
  def change
    create_table :api_key_scopes do |t|
      t.integer :api_key_id, null: false
      t.string :resource, null: false
      t.string :action, null: false
      t.json :allowed_parameters
      t.timestamps
    end

    add_index :api_key_scopes, :api_key_id
  end
end
