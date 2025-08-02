# frozen_string_literal: true

class AddHiddenToApiKeys < ActiveRecord::Migration[4.2]
  def change
    change_table :api_keys do |t|
      t.boolean :hidden, null: false, default: false
    end
  end
end
