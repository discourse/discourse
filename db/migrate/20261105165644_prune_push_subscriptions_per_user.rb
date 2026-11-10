# frozen_string_literal: true

class PrunePushSubscriptionsPerUser < ActiveRecord::Migration[8.1]
  MAX_SUBSCRIPTIONS_PER_USER = 10

  def up
    DB.exec(<<~SQL, max: MAX_SUBSCRIPTIONS_PER_USER)
      DELETE FROM push_subscriptions
      WHERE id IN (
        SELECT id
        FROM (
          SELECT id, ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY id DESC) AS position
          FROM push_subscriptions
        ) ranked
        WHERE position > :max
      )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
