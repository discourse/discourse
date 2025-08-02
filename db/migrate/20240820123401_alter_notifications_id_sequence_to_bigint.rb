# frozen_string_literal: true

class AlterNotificationsIdSequenceToBigint < ActiveRecord::Migration[7.0]
  def up
    execute "ALTER SEQUENCE notifications_id_seq AS bigint"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
