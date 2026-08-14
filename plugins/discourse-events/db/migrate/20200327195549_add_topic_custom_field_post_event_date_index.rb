# frozen_string_literal: true

class AddTopicCustomFieldPostEventDateIndex < ActiveRecord::Migration[6.0]
  def change
    add_index :topic_custom_fields,
              %i[name topic_id],
              name: :idx_topic_custom_fields_post_event_starts_at,
              unique: true,
              where: "name = '#{DiscoursePostEvent::TOPIC_POST_EVENT_STARTS_AT}'"
  end
end
