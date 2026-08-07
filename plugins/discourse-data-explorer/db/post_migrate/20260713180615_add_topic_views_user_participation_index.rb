# frozen_string_literal: true
class AddTopicViewsUserParticipationIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    remove_index :topic_views,
                 name: "index_topic_views_for_user_participation",
                 algorithm: :concurrently,
                 if_exists: true

    add_index :topic_views,
              %i[viewed_at user_id topic_id],
              where: "user_id IS NOT NULL",
              name: "index_topic_views_for_user_participation",
              algorithm: :concurrently
  end

  def down
    remove_index :topic_views,
                 name: "index_topic_views_for_user_participation",
                 algorithm: :concurrently,
                 if_exists: true
  end
end
