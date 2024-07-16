# frozen_string_literal: true
class AddSmtpSslModeToGroups < ActiveRecord::Migration[7.1]
  def change
    add_column :groups, :smtp_ssl_mode, :integer, default: 0, null: false

    execute <<~SQL
      UPDATE groups SET smtp_ssl_mode = (CASE WHEN smtp_ssl THEN 2 ELSE 0 END)
    SQL
  end
end
