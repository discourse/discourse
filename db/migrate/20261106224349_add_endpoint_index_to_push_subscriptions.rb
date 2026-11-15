# frozen_string_literal: true

class AddEndpointIndexToPushSubscriptions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    # jsonb rejects \u0000, so these legacy rows would fail the index build.
    execute "DELETE FROM push_subscriptions WHERE strpos(data, '\\u0000') > 0"

    remove_index :push_subscriptions,
                 name: "index_push_subscriptions_on_endpoint",
                 algorithm: :concurrently,
                 if_exists: true

    # Partial so oversized endpoints and \u0000 rows the build can still see can't fail it.
    add_index :push_subscriptions,
              "(data::jsonb ->> 'endpoint')",
              name: "index_push_subscriptions_on_endpoint",
              where:
                "strpos(data, '\\u0000') = 0 AND octet_length(data::jsonb ->> 'endpoint') <= 2048",
              algorithm: :concurrently
  end

  def down
    remove_index :push_subscriptions,
                 name: "index_push_subscriptions_on_endpoint",
                 algorithm: :concurrently,
                 if_exists: true
  end
end
