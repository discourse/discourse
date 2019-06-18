# frozen_string_literal: true

class AddLikedAndBookmarkedToTopicUser < ActiveRecord::Migration[4.2]
  def up
    add_column :topic_users, :liked, :boolean, default: false
    add_column :topic_users, :bookmarked, :boolean, default: false

    # likes and bookmarks PostActionType.types[:like] and :bookmark which should not be used in a migration
    { liked: 2, bookmarked: 1 }.each do |name, type|
      execute "UPDATE topic_users
               SET #{name} = true
               WHERE EXISTS (SELECT 1 FROM post_actions pa
                             JOIN posts p ON p.id = pa.post_id
                             JOIN topics t ON t.id = p.topic_id
                             WHERE pa.deleted_at IS NULL AND
                                   p.deleted_at IS NULL AND
                                   t.deleted_at IS NULL AND
                                   pa.user_id = topic_users.user_id AND
                                   p.topic_id = topic_users.topic_id AND
                                   post_action_type_id = #{type})
    "
    end

  end

  def down
    remove_column :topic_users, :liked
    remove_column :topic_users, :bookmarked
  end
end
