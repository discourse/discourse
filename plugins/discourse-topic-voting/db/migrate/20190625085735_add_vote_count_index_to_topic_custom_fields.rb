# frozen_string_literal: true

class AddVoteCountIndexToTopicCustomFields < ActiveRecord::Migration[5.2]
  def change
    execute <<~SQL
      DELETE FROM topic_custom_fields f
      WHERE name = 'vote_count' AND id > (
        SELECT MIN(f2.id) FROM topic_custom_fields f2
          WHERE f2.topic_id = f.topic_id AND f2.name = f.name
      )
    SQL

    add_index :topic_custom_fields, :topic_id, unique: true, where: "name = 'vote_count'"
  end
end
