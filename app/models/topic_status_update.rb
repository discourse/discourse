class TopicStatusUpdate < ActiveRecord::Base
  include Trashable

  belongs_to :user
  belongs_to :topic
  belongs_to :category

  validates :user_id, presence: true
  validates :topic_id, presence: true
  validates :execute_at, presence: true
  validates :status_type, presence: true
  validates :status_type, uniqueness: { scope: [:topic_id, :deleted_at] }
  validates :category_id, presence: true, if: :publishing_to_category?

  validate :ensure_update_will_happen

  before_save do
    self.created_at ||= Time.zone.now if execute_at

    if (execute_at_changed? && !execute_at_was.nil?) || user_id_changed?
      self.send("cancel_auto_#{self.class.types[status_type]}_job")
    end
  end

  after_save do
    if (execute_at_changed? || user_id_changed?)
      now = Time.zone.now
      time = execute_at < now ? now : execute_at

      self.send("schedule_auto_#{self.class.types[status_type]}_job", time)
    end
  end

  def self.types
    @types ||= Enum.new(
      close: 1,
      open: 2,
      publish_to_category: 3
    )
  end

  def self.ensure_consistency!
    TopicStatusUpdate.where("topic_status_updates.execute_at < ?", Time.zone.now)
      .find_each do |topic_status_update|

      topic_status_update.send(
        "schedule_auto_#{self.types[topic_status_update.status_type]}_job",
        topic_status_update.execute_at
      )
    end
  end

  def duration
    if (self.execute_at && self.created_at)
      ((self.execute_at - self.created_at) / 1.hour).round(2)
    else
      0
    end
  end

  private

    def ensure_update_will_happen
      if created_at && (execute_at < created_at)
        errors.add(:execute_at, I18n.t(
          'activerecord.errors.models.topic_status_update.attributes.execute_at.in_the_past'
        ))
      end
    end

    def cancel_auto_close_job
      Jobs.cancel_scheduled_job(:toggle_topic_closed, topic_status_update_id: id)
    end
    alias_method :cancel_auto_open_job, :cancel_auto_close_job

    def cancel_auto_publish_to_category_job
      Jobs.cancel_scheduled_job(:publish_topic_to_category, topic_status_update_id: id)
    end

    def schedule_auto_open_job(time)
      return unless topic
      topic.update_status('closed', true, user) if !topic.closed

      Jobs.enqueue_at(time, :toggle_topic_closed,
        topic_status_update_id: id,
        state: false
      )
    end

    def schedule_auto_close_job(time)
      return unless topic
      topic.update_status('closed', false, user) if topic.closed

      Jobs.enqueue_at(time, :toggle_topic_closed,
        topic_status_update_id: id,
        state: true
      )
    end

    def schedule_auto_publish_to_category_job(time)
      Jobs.enqueue_at(time, :publish_topic_to_category, topic_status_update_id: id)
    end

    def publishing_to_category?
      self.status_type.to_i == TopicStatusUpdate.types[:publish_to_category]
    end
end

# == Schema Information
#
# Table name: topic_status_updates
#
#  id                 :integer          not null, primary key
#  execute_at         :datetime         not null
#  status_type        :integer          not null
#  user_id            :integer          not null
#  topic_id           :integer          not null
#  based_on_last_post :boolean          default(FALSE), not null
#  deleted_at         :datetime
#  deleted_by_id      :integer
#  created_at         :datetime
#  updated_at         :datetime
#  category_id        :integer
#
# Indexes
#
#  idx_topic_id_status_type_deleted_at    (topic_id,status_type) UNIQUE
#  index_topic_status_updates_on_user_id  (user_id)
#
