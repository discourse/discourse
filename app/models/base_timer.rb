# frozen_string_literal: true

class BaseTimer < ActiveRecord::Base
  self.table_name = "topic_timers"

  MAX_DURATION_MINUTES = 20.years.to_i / 60

  include Trashable

  validates :status_type, presence: true
  validates :category_id, presence: true, if: :publishing_to_category?

  validate :duration_in_range?

  def status_type_name
    self.class.types[status_type]
  end

  def enqueue_typed_job(time: nil)
    self.send("schedule_auto_#{status_type_name}_job")
  end

  def self.type_job_map
    {
      close: :close_topic,
      open: :open_topic,
      publish_to_category: :publish_topic_to_category,
      delete: :delete_topic,
      reminder: :topic_reminder,
      bump: :bump_topic,
      delete_replies: :delete_replies,
      silent_close: :close_topic,
      clear_slow_mode: :clear_slow_mode,
    }
  end

  def self.types
    @types ||=
      Enum.new(
        close: 1,
        open: 2,
        publish_to_category: 3,
        delete: 4,
        reminder: 5,
        bump: 6,
        delete_replies: 7,
        silent_close: 8,
        clear_slow_mode: 9,
      )
  end

  def self.public_types
    @_public_types ||= types.except(:reminder, :clear_slow_mode)
  end

  def self.private_types
    @_private_types ||= types.only(:reminder, :clear_slow_mode)
  end

  def self.destructive_types
    @_destructive_types ||= types.only(:delete, :delete_replies)
  end

  def public_type?
    !!self.class.public_types[self.status_type]
  end

  def private_type?
    !!self.class.private_types[self.status_type]
  end

  def publishing_to_category?
    self.status_type.to_i == TopicTimer.types[:publish_to_category]
  end

  private

  def duration_in_range?
    return if duration_minutes.blank?

    if duration_minutes.to_i <= 0
      errors.add(
        :duration_minutes,
        I18n.t("activerecord.errors.models.topic_timer.attributes.duration_minutes.cannot_be_zero"),
      )
    end

    if duration_minutes.to_i > MAX_DURATION_MINUTES
      errors.add(
        :duration_minutes,
        I18n.t(
          "activerecord.errors.models.topic_timer.attributes.duration_minutes.exceeds_maximum",
        ),
      )
    end
  end
end

# == Schema Information
#
# Table name: topic_timers
#
#  id                 :integer          not null, primary key
#  based_on_last_post :boolean          default(FALSE), not null
#  deleted_at         :datetime
#  duration_minutes   :integer
#  execute_at         :datetime         not null
#  public_type        :boolean          default(TRUE)
#  status_type        :integer          not null
#  type               :string           default("TopicTimer"), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  category_id        :integer
#  deleted_by_id      :integer
#  topic_id           :integer          not null
#  user_id            :integer          not null
#
# Indexes
#
#  idx_topic_id_public_type_deleted_at  (topic_id) UNIQUE WHERE ((public_type = true) AND (deleted_at IS NULL) AND ((type)::text = 'TopicTimer'::text))
#  index_topic_timers_on_topic_id       (topic_id) WHERE (deleted_at IS NULL)
#  index_topic_timers_on_user_id        (user_id)
#
