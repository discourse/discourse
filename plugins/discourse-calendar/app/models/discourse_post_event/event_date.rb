# frozen_string_literal: true

module DiscoursePostEvent
  class EventDate < ActiveRecord::Base
    self.table_name = "discourse_calendar_post_event_dates"
    belongs_to :event

    scope :pending,
          -> do
            where(finished_at: nil).joins(:event).where(
              "discourse_post_event_events.deleted_at is NULL",
            )
          end
    scope :expired, -> { where("ends_at IS NOT NULL AND ends_at < ?", Time.now) }
    scope :not_expired, -> { where("ends_at IS NULL OR ends_at > ?", Time.now) }

    after_commit :upsert_topic_custom_field, on: %i[create]
    def upsert_topic_custom_field
      if self.event.post && self.event.post.is_first_post?
        TopicCustomField.upsert(
          {
            topic_id: self.event.post.topic_id,
            name: TOPIC_POST_EVENT_STARTS_AT,
            value: self.starts_at,
            created_at: Time.now,
            updated_at: Time.now,
          },
          unique_by: "idx_topic_custom_fields_topic_post_event_starts_at",
        )

        TopicCustomField.upsert(
          {
            topic_id: self.event.post.topic_id,
            name: TOPIC_POST_EVENT_ENDS_AT,
            value: self.ends_at,
            created_at: Time.now,
            updated_at: Time.now,
          },
          unique_by: "idx_topic_custom_fields_topic_post_event_ends_at",
        )
      end
    end

    def started?
      starts_at <= Time.current
    end

    def ended?
      (ends_at || starts_at.end_of_day) <= Time.current
    end
  end
end

# == Schema Information
#
# Table name: discourse_calendar_post_event_dates
#
#  id                       :bigint           not null, primary key
#  event_id                 :integer
#  starts_at                :datetime
#  ends_at                  :datetime
#  reminder_counter         :integer          default(0)
#  event_will_start_sent_at :datetime
#  event_started_sent_at    :datetime
#  finished_at              :datetime
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
# Indexes
#
#  index_discourse_calendar_post_event_dates_on_event_id     (event_id)
#  index_discourse_calendar_post_event_dates_on_finished_at  (finished_at)
#
