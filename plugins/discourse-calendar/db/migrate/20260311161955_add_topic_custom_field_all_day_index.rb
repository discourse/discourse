# frozen_string_literal: true

class AddTopicCustomFieldAllDayIndex < ActiveRecord::Migration[8.0]
  def change
    add_index :topic_custom_fields,
              %i[name topic_id],
              name: :idx_topic_custom_fields_topic_post_event_all_day,
              unique: true,
              where: "name = '#{DiscoursePostEvent::TOPIC_POST_EVENT_ALL_DAY}'"
  end
end
