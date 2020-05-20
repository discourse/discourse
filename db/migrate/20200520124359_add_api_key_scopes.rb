# frozen_string_literal: true

class AddApiKeyScopes < ActiveRecord::Migration[6.0]
  def change
    create_table :api_key_scopes do |t|
      t.integer :api_key_id
      t.string :resource
      t.string :action
      t.json :allowed_parameters
    end
  end
end
