# frozen_string_literal: true

class AddUniqueIndexToTopicEventEndsAtCustomField < ActiveRecord::Migration[6.0]
  def up
    add_index :topic_custom_fields,
              %i[name topic_id],
              name: :idx_topic_custom_fields_topic_post_event_ends_at,
              unique: true,
              where: "name = '#{DiscoursePostEvent::TOPIC_POST_EVENT_ENDS_AT}'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
