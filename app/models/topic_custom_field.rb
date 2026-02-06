# frozen_string_literal: true

class TopicCustomField < ActiveRecord::Base
  include CustomField

  belongs_to :topic
end

# == Schema Information
#
# Table name: topic_custom_fields
#
#  id         :integer          not null, primary key
#  name       :string(256)      not null
#  value      :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  topic_id   :integer          not null
#
# Indexes
#
#  idx_topic_custom_fields_accepted_answer                       (topic_id) UNIQUE WHERE ((name)::text = 'accepted_answer_post_id'::text)
#  idx_topic_custom_fields_auto_responder_triggered_ids_partial  (topic_id,value) UNIQUE WHERE ((name)::text = 'auto_responder_triggered_ids'::text)
#  idx_topic_custom_fields_topic_post_event_ends_at              (name,topic_id) UNIQUE WHERE ((name)::text = 'TopicEventEndsAt'::text)
#  idx_topic_custom_fields_topic_post_event_starts_at            (name,topic_id) UNIQUE WHERE ((name)::text = 'TopicEventStartsAt'::text)
#  index_topic_custom_fields_on_topic_id                         (topic_id) UNIQUE WHERE ((name)::text = 'vote_count'::text)
#  index_topic_custom_fields_on_topic_id_and_name                (topic_id,name)
#  index_topic_custom_fields_on_topic_id_and_slack_thread_id     (topic_id,name) UNIQUE WHERE ((name)::text ~~ 'slack_thread_id_%'::text)
#  topic_custom_fields_value_key_idx                             (value,name) WHERE ((value IS NOT NULL) AND (char_length(value) < 400))
#
