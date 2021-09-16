# frozen_string_literal: true

require 'migration/table_dropper'

class AddArchiveAtToTopicAllowedUsers < ActiveRecord::Migration[6.1]
  def up
    %w{
      user_archived_messages
      group_archived_messages
    }.each do |table_name|
      Migration::TableDropper.read_only_table(table_name)
    end

    add_column :topic_allowed_users, :archived_at, :datetime, null: true
    add_column :topic_allowed_groups, :archived_at, :datetime, null: true

    execute <<~SQL
      UPDATE topic_allowed_users
      SET archived_at = uam.created_at
      FROM topic_allowed_users AS tau
      INNER JOIN user_archived_messages uam
        ON uam.topic_id = tau.topic_id AND uam.user_id = tau.user_id
      WHERE topic_allowed_users.topic_id = tau.topic_id
        AND topic_allowed_users.user_id = tau.user_id
    SQL

    execute <<~SQL
      UPDATE topic_allowed_groups
      SET archived_at = gam.created_at
      FROM topic_allowed_groups AS tag
      INNER JOIN group_archived_messages gam
        ON gam.topic_id = tag.topic_id AND gam.group_id = tag.group_id
      WHERE topic_allowed_groups.topic_id = tag.topic_id
        AND topic_allowed_groups.group_id = tag.group_id
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
