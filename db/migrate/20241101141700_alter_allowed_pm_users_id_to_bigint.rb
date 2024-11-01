# frozen_string_literal: true

class AlterAllowedPmUsersIdToBigint < ActiveRecord::Migration[7.1]
  def up
    change_column :allowed_pm_users, :allowed_pm_user_id, :bigint
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
