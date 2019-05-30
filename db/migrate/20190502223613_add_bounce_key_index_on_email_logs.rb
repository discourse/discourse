# frozen_string_literal: true

class AddBounceKeyIndexOnEmailLogs < ActiveRecord::Migration[5.2]
  def change
    add_index :email_logs, [:bounce_key], unique: true, where: 'bounce_key IS NOT NULL'
  end
end
