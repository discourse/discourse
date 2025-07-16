# frozen_string_literal: true

class Assignment < ActiveRecord::Base
  VALID_TYPES = %w[topic post].freeze

  belongs_to :topic
  belongs_to :assigned_to, polymorphic: true
  belongs_to :assigned_by_user, class_name: "User"
  belongs_to :target, polymorphic: true

  scope :joins_with_topics,
        -> do
          joins(
            "INNER JOIN topics ON topics.id = assignments.target_id AND assignments.target_type = 'Topic' AND topics.deleted_at IS NULL",
          )
        end

  scope :active_for_group, ->(group) { active.where(assigned_to: group) }
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  before_validation :default_status

  validate :validate_status, if: -> { SiteSetting.enable_assign_status }

  class << self
    def valid_type?(type)
      VALID_TYPES.include?(type.downcase)
    end

    def statuses
      SiteSetting.assign_statuses.split("|")
    end

    def default_status
      Assignment.statuses.first
    end

    def status_enabled?
      SiteSetting.enable_assign_status
    end

    def deactivate!(topic:)
      active.where(topic: topic).find_each(&:deactivate!)
    end

    def reactivate!(topic:)
      inactive.where(topic: topic).find_each(&:reactivate!)
    end
  end

  def assigned_to_user?
    assigned_to.is_a?(User)
  end

  def assigned_to_group?
    assigned_to.is_a?(Group)
  end

  def assigned_users
    Array.wrap(assigned_to.try(:users) || assigned_to)
  end

  def post
    return target.posts.find_by(post_number: 1) if target.is_a?(Topic)
    target
  end

  def create_missing_notifications!
    assigned_users.each do |user|
      next if user.notifications.for_assignment(self).exists?
      DiscourseAssign::CreateNotification.call(
        assignment: self,
        user: user,
        mark_as_read: assigned_by_user == user,
      )
    end
  end

  def reactivate!
    return unless target
    update!(active: true)
    Jobs.enqueue(:assign_notification, assignment_id: id)
  end

  def deactivate!
    update!(active: false)
    Jobs.enqueue(
      :unassign_notification,
      topic_id: topic_id,
      assigned_to_id: assigned_to_id,
      assigned_to_type: assigned_to_type,
      assignment_id: id,
    )
  end

  private

  def default_status
    self.status ||= Assignment.default_status if SiteSetting.enable_assign_status
  end

  def validate_status
    if SiteSetting.enable_assign_status && !Assignment.statuses.include?(self.status)
      errors.add(:status, :invalid)
    end
  end
end

# == Schema Information
#
# Table name: assignments
#
#  id                  :bigint           not null, primary key
#  topic_id            :integer          not null
#  assigned_to_id      :integer          not null
#  assigned_by_user_id :integer          not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  assigned_to_type    :string           not null
#  target_id           :integer          not null
#  target_type         :string           not null
#  active              :boolean          default(TRUE)
#  note                :string
#  status              :text
#
# Indexes
#
#  index_assignments_on_active                               (active)
#  index_assignments_on_assigned_to_id_and_assigned_to_type  (assigned_to_id,assigned_to_type)
#  index_assignments_on_target_id_and_target_type            (target_id,target_type) UNIQUE
#  index_assignments_on_topic_id                             (topic_id)
#  unique_target_and_assigned                                (assigned_to_id,assigned_to_type,target_id,target_type) UNIQUE
#
