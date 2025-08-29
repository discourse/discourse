# frozen_string_literal: true

class TopicTimer < BaseTimer
  belongs_to :user
  belongs_to :topic
  belongs_to :category

  validates :user_id, presence: true
  validates :topic_id, presence: true
  validates :execute_at, presence: true
  validates :status_type, uniqueness: { scope: %i[topic_id deleted_at] }, if: :public_type?
  validates :status_type, uniqueness: { scope: %i[topic_id deleted_at user_id] }, if: :private_type?

  validate :executed_at_in_future?

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

  def runnable?
    return false if deleted_at.present?
    return false if execute_at > Time.zone.now
    true
  end

  private

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
