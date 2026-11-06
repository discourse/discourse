# frozen_string_literal: true

class AddEndpointIndexToPushSubscriptions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    remove_index :push_subscriptions,
                 name: "index_push_subscriptions_on_endpoint",
                 algorithm: :concurrently,
                 if_exists: true

    # Partial so legacy endpoints over the B-tree tuple limit can't fail the build.
    add_index :push_subscriptions,
              "(data::jsonb ->> 'endpoint')",
              name: "index_push_subscriptions_on_endpoint",
              where: "octet_length(data::jsonb ->> 'endpoint') <= 2048",
              algorithm: :concurrently
  end
end
