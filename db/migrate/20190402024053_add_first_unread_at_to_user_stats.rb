# frozen_string_literal: true

class AddFirstUnreadAtToUserStats < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    # so we can rerun this if the index creation fails out of ddl
    if !column_exists?(:user_stats, :first_unread_at)
      add_column :user_stats, :first_unread_at, :datetime, null: false, default: -> { 'CURRENT_TIMESTAMP' }
    end

    execute <<~SQL
      UPDATE user_stats us
      SET first_unread_at = u.created_at
      FROM users u
      WHERE u.id = us.user_id
    SQL

    # since DDL transactions are disabled we got to check
    # this could potentially fail half way and we want it to recover
    if !index_exists?(
      :topics,
      # the big list of columns here is not really needed, but ... why not
      [:updated_at, :visible, :highest_staff_post_number, :highest_post_number, :category_id, :created_at, :id],
      name: 'index_topics_on_updated_at_public'
    )
      # this is quite a big index to carry, but we need it to optimise home page initial load
      # by covering all these columns we are able to quickly retrieve the set of topics that were
      # updated in the last N days. We perform a ranged lookup and selectivity may vary a lot
      add_index :topics,
        [:updated_at, :visible, :highest_staff_post_number, :highest_post_number, :category_id, :created_at, :id],
        algorithm: :concurrently,
        name: 'index_topics_on_updated_at_public',
        where: "(topics.archetype <> 'private_message') AND (topics.deleted_at IS NULL)"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
