# frozen_string_literal: true

class TopicTimer < ActiveRecord::Base
  include Trashable

  belongs_to :user
  belongs_to :topic
  belongs_to :category

  validates :user_id, presence: true
  validates :topic_id, presence: true
  validates :execute_at, presence: true
  validates :status_type, presence: true
  validates :status_type, uniqueness: { scope: [:topic_id, :deleted_at] }, if: :public_type?
  validates :status_type, uniqueness: { scope: [:topic_id, :deleted_at, :user_id] }, if: :private_type?
  validates :category_id, presence: true, if: :publishing_to_category?

  validate :ensure_update_will_happen

  scope :scheduled_bump_topics, -> { where(status_type: TopicTimer.types[:bump], deleted_at: nil).pluck(:topic_id) }

  before_save do
    self.created_at ||= Time.zone.now if execute_at
    self.public_type = self.public_type?

    if (will_save_change_to_execute_at? &&
       !attribute_in_database(:execute_at).nil?) ||
       will_save_change_to_user_id?

      # private implementation detail have to use send
      self.send("cancel_auto_#{self.class.types[status_type]}_job")
    end
  end

  after_save do
    if (saved_change_to_execute_at? || saved_change_to_user_id?)
      now = Time.zone.now
      time = execute_at < now ? now : execute_at

      # private implementation detail have to use send
      self.send("schedule_auto_#{self.class.types[status_type]}_job", time)
    end
  end

  def self.types
    @types ||= Enum.new(
      close: 1,
      open: 2,
      publish_to_category: 3,
      delete: 4,
      reminder: 5,
      bump: 6,
      delete_replies: 7,
      silent_close: 8,
      clear_slow_mode: 9
    )
  end

  def self.public_types
    @_public_types ||= types.except(:reminder, :clear_slow_mode)
  end

  def self.private_types
    @_private_types ||= types.only(:reminder, :clear_slow_mode)
  end

  def self.ensure_consistency!
    TopicTimer.where("topic_timers.execute_at < ?", Time.zone.now)
      .find_each do |topic_timer|

      # private implementation detail scoped to class
      topic_timer.send(
        "schedule_auto_#{self.types[topic_timer.status_type]}_job",
        topic_timer.execute_at
      )
    end
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

  private

  def ensure_update_will_happen
    if created_at && (execute_at < created_at)
      errors.add(:execute_at, I18n.t(
        'activerecord.errors.models.topic_timer.attributes.execute_at.in_the_past'
      ))
    end
  end

  # TODO(martin - 2021-05-01) - Remove cancels for toggle_topic_closed once topic timer revamp completed.
  def cancel_auto_close_job
    Jobs.cancel_scheduled_job(:toggle_topic_closed, topic_timer_id: id)
    Jobs.cancel_scheduled_job(:close_topic, topic_timer_id: id)
  end

  # TODO(martin - 2021-05-01) - Remove cancels for toggle_topic_closed once topic timer revamp completed.
  def cancel_auto_open_job
    Jobs.cancel_scheduled_job(:toggle_topic_closed, topic_timer_id: id)
    Jobs.cancel_scheduled_job(:open_topic, topic_timer_id: id)
  end

  # TODO(martin - 2021-05-01) - Remove cancels for toggle_topic_closed once topic timer revamp completed.
  def cancel_auto_silent_close_job
    Jobs.cancel_scheduled_job(:toggle_topic_closed, topic_timer_id: id)
    Jobs.cancel_scheduled_job(:close_topic, topic_timer_id: id)
  end

  def cancel_auto_publish_to_category_job
    Jobs.cancel_scheduled_job(:publish_topic_to_category, topic_timer_id: id)
  end

  def cancel_auto_delete_job
    Jobs.cancel_scheduled_job(:delete_topic, topic_timer_id: id)
  end

  def cancel_auto_reminder_job
    Jobs.cancel_scheduled_job(:topic_reminder, topic_timer_id: id)
  end

  def cancel_auto_bump_job
    Jobs.cancel_scheduled_job(:bump_topic, topic_timer_id: id)
  end

  def cancel_auto_delete_replies_job
    Jobs.cancel_scheduled_job(:delete_replies, topic_timer_id: id)
  end

  def cancel_auto_clear_slow_mode_job
    Jobs.cancel_scheduled_job(:clear_slow_mode, topic_timer_id: id)
  end

  def schedule_auto_delete_replies_job(time)
    Jobs.enqueue_at(time, :delete_replies, topic_timer_id: id)
  end

  def schedule_auto_bump_job(time)
    Jobs.enqueue_at(time, :bump_topic, topic_timer_id: id)
  end

  def schedule_auto_open_job(time)
    topic.update_status('closed', true, user) if topic && !topic.closed

    Jobs.enqueue_at(time, :open_topic, topic_timer_id: id)
  end

  def schedule_auto_close_job(time)
    topic.update_status('closed', false, user) if topic&.closed

    Jobs.enqueue_at(time, :close_topic, topic_timer_id: id)
  end

  def schedule_auto_silent_close_job(time)
    topic.update_status('closed', false, user) if topic&.closed

    Jobs.enqueue_at(time, :close_topic, topic_timer_id: id, silent: true)
  end

  def schedule_auto_publish_to_category_job(time)
    Jobs.enqueue_at(time, :publish_topic_to_category, topic_timer_id: id)
  end

  def publishing_to_category?
    self.status_type.to_i == TopicTimer.types[:publish_to_category]
  end

  def schedule_auto_delete_job(time)
    Jobs.enqueue_at(time, :delete_topic, topic_timer_id: id)
  end

  def schedule_auto_reminder_job(time)
    # noop, TODO(martin 2021-03-11): Remove this after timers migrated and outstanding jobs cancelled
  end

  def schedule_auto_clear_slow_mode_job(time)
    Jobs.enqueue_at(time, :clear_slow_mode, topic_timer_id: id)
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
#  duration           :integer
#
# Indexes
#
#  idx_topic_id_public_type_deleted_at  (topic_id) UNIQUE WHERE ((public_type = true) AND (deleted_at IS NULL))
#  index_topic_timers_on_user_id        (user_id)
#
