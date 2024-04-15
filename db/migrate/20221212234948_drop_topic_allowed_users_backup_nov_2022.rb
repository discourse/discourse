# frozen_string_literal: true

class DropTopicAllowedUsersBackupNov2022 < ActiveRecord::Migration[7.0]
  def up
    # Follow-up to RemoveInvalidTopicAllowedUsersFromInvites
    DB.exec("DROP TABLE IF EXISTS topic_allowed_users_backup_nov_2022")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
