# frozen_string_literal: true

class TopicTimer < ActiveRecord::Base
  MAX_DURATION_MINUTES = 20.years.to_i / 60

  include Trashable

  belongs_to :user
  belongs_to :topic
  belongs_to :category

  validates :user_id, presence: true
  validates :topic_id, presence: true
  validates :execute_at, presence: true
  validates :status_type, presence: true
  validates :status_type, uniqueness: { scope: %i[topic_id deleted_at] }, if: :public_type?
  validates :status_type, uniqueness: { scope: %i[topic_id deleted_at user_id] }, if: :private_type?
  validates :category_id, presence: true, if: :publishing_to_category?

  validate :executed_at_in_future?
  validate :duration_in_range?

  scope :scheduled_bump_topics,
        -> { where(status_type: TopicTimer.types[:bump], deleted_at: nil).pluck(:topic_id) }
  scope :pending_timers,
        ->(before_time = Time.now.utc) do
          where("execute_at <= :before_time AND deleted_at IS NULL", before_time: before_time)
        end

  before_save do
    self.created_at ||= Time.zone.now if execute_at
    self.public_type = self.public_type?
  end

  # These actions are in place to make sure the topic is in the correct
  # state at the point in time where the timer is saved. It does not
  # guarantee that the topic will be in the correct state when the timer
  # job is executed, but each timer job handles deleted topics etc. gracefully.
  #
  # This is also important for the Open Temporarily and Close Temporarily timers,
  # which change the topic's status straight away and set a timer to do the
  # opposite action in the future.
  after_save do
    if (saved_change_to_execute_at? || saved_change_to_user_id?)
      if status_type == TopicTimer.types[:silent_close] || status_type == TopicTimer.types[:close]
        topic.update_status("closed", false, user) if topic.closed?
      end
      if status_type == TopicTimer.types[:open]
        topic.update_status("closed", true, user) if topic.open?
      end
    end
  end

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

  def runnable?
    return false if deleted_at.present?
    return false if execute_at > Time.zone.now
    true
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

  def executed_at_in_future?
    return if created_at.blank? || (execute_at > created_at)

    errors.add(
      :execute_at,
      I18n.t("activerecord.errors.models.topic_timer.attributes.execute_at.in_the_past"),
    )
  end

  def schedule_auto_delete_replies_job
    Jobs.enqueue(TopicTimer.type_job_map[:delete_replies], topic_timer_id: id)
  end

  def schedule_auto_bump_job
    Jobs.enqueue(TopicTimer.type_job_map[:bump], topic_timer_id: id)
  end

  def schedule_auto_open_job
    Jobs.enqueue(TopicTimer.type_job_map[:open], topic_timer_id: id)
  end

  def schedule_auto_close_job
    Jobs.enqueue(TopicTimer.type_job_map[:close], topic_timer_id: id)
  end

  def schedule_auto_silent_close_job
    Jobs.enqueue(TopicTimer.type_job_map[:close], topic_timer_id: id, silent: true)
  end

  def schedule_auto_publish_to_category_job
    Jobs.enqueue(TopicTimer.type_job_map[:publish_to_category], topic_timer_id: id)
  end

  def schedule_auto_delete_job
    Jobs.enqueue(TopicTimer.type_job_map[:delete], topic_timer_id: id)
  end

  def schedule_auto_clear_slow_mode_job
    Jobs.enqueue(TopicTimer.type_job_map[:clear_slow_mode], topic_timer_id: id)
  end
end

# == Schema Information
#
# Table name: topic_timers
#
#  id                 :integer          not null, primary key
#  execute_at         :datetime         not null
#  status_type        :integer          not null
#  user_id            :integer          not null
#  topic_id           :integer          not null
#  based_on_last_post :boolean          default(FALSE), not null
#  deleted_at         :datetime
#  deleted_by_id      :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  category_id        :integer
#  public_type        :boolean          default(TRUE)
#  duration_minutes   :integer
#
# Indexes
#
#  idx_topic_id_public_type_deleted_at  (topic_id) UNIQUE WHERE ((public_type = true) AND (deleted_at IS NULL))
#  index_topic_timers_on_topic_id       (topic_id) WHERE (deleted_at IS NULL)
#  index_topic_timers_on_user_id        (user_id)
#
