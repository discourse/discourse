# frozen_string_literal: true

require 'migration/column_dropper'

class MigrateInviteRedeemedDataToInvitedUsers < ActiveRecord::Migration[6.0]
  def up
    %i{user_id redeemed_at}.each do |column|
      Migration::ColumnDropper.mark_readonly(:invites, column)
    end

    execute <<~SQL
      INSERT INTO invited_users (
        user_id,
        invite_id,
        redeemed_at,
        created_at,
        updated_at
      )
      SELECT user_id, id, redeemed_at, created_at, updated_at
      FROM invites
      WHERE user_id IS NOT NULL AND redeemed_at IS NOT NULL
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
