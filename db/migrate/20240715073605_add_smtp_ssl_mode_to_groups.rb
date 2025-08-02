# frozen_string_literal: true
class AddSmtpSslModeToGroups < ActiveRecord::Migration[7.1]
  def up
    add_column :groups, :smtp_ssl_mode, :integer, default: 0, null: false

    execute <<~SQL
      UPDATE groups SET smtp_ssl_mode = (CASE WHEN smtp_ssl THEN 2 ELSE 0 END)
    SQL

    Migration::ColumnDropper.mark_readonly(:groups, :smtp_ssl)
  end

  def down
    Migration::ColumnDropper.drop_readonly(:groups, :smtp_ssl)
    remove_column :groups, :smtp_ssl_mode
  end
end
