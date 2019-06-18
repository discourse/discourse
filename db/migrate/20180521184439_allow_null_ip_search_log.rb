# frozen_string_literal: true

class AllowNullIpSearchLog < ActiveRecord::Migration[5.1]
  def up
    begin
      Migration::SafeMigrate.disable!
      change_column :search_logs, :ip_address, :inet, null: true
    ensure
      Migration::SafeMigrate.enable!
    end
  end

  def down
  end
end
