# frozen_string_literal: true

require_relative "../../lib/discourse_assign/assignment_permissions"

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
    def version_for(topic)
      Digest::SHA256.hexdigest(
        where(topic:).order(:id).pluck(:id, :updated_at, :active, :note, :status).to_json,
      )
    end

    def multiple_assignments_ready?
      !connection.index_exists?(
        :assignments,
        %i[target_id target_type],
        name: "index_assignments_on_target_id_and_target_type",
        unique: true,
      )
    end

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
      topic.with_lock { active.where(topic: topic).find_each(&:deactivate!) }
    end

    def reactivate!(topic:)
      topic.with_lock { inactive.where(topic: topic).find_each(&:reactivate!) }
    end
  end

  def assigned_to_user?
    assigned_to.is_a?(User)
  end

  def assigned_to_group?
    assigned_to.is_a?(Group)
  end

  def assigned_users(user_id: nil)
    if assigned_to_group?
      members = assigned_to.users
      members = members.where(id: user_id) if user_id
      members.to_a
    elsif user_id.nil? || assigned_to&.id == user_id
      Array.wrap(assigned_to)
    else
      []
    end
  end

  def post
    return target.posts.find_by(post_number: 1) if target.is_a?(Topic)
    target
  end

  def create_missing_notifications!(user_id: nil)
    return unless active && target && assigned_to

    topic.with_lock do
      return unless Assignment.active.exists?(id: id)
      assigned_users(user_id:).each do |user|
        next if user.notifications.for_assignment(self).where(topic_id:).exists?
        if target_type == "Topic"
          direct_ids = Assignment.where(topic_id:, target_type: "Topic").select(:id)
          next if user.notifications.for_assignment(direct_ids).exists?
        end
        DiscourseAssign::CreateNotification.call(
          assignment: self,
          user: user,
          mark_as_read: assigned_by_user == user,
        )
      end
    end
  end

  def reactivate!
    return unless target
    topic.with_lock do
      if !active &&
           Assignment.active.where(topic:).count >= SiteSetting.assign_max_assignments_per_topic
        return
      end
      update!(active: true)
      ActiveRecord.after_all_transactions_commit do
        Jobs.enqueue(:assign_notification, assignment_id: id)
        publish_topic_assignment
      end
    end
  end

  def deactivate!
    update!(active: false)
    ActiveRecord.after_all_transactions_commit do
      Jobs.enqueue(
        :unassign_notification,
        topic_id: topic_id,
        assigned_to_id: assigned_to_id,
        assigned_to_type: assigned_to_type,
        assignment_id: id,
      )
    end
  end

  def publish_topic_assignment
    return if !assigned_to

    allowed_user_ids =
      DiscourseAssign::AssignmentPermissions.assignable_user_ids(target || topic).pluck(:id)
    return if allowed_user_ids.blank?

    if target_type == "Topic" && SiteSetting.assign_allow_multiple_topic_assignees
      MessageBus.publish(
        "/staff/topic-assignment",
        { type: "changed", topic_id: },
        user_ids: allowed_user_ids,
      )
      return
    end

    serializer_class = assigned_to_user? ? BasicUserSerializer : BasicGroupSerializer
    MessageBus.publish(
      "/staff/topic-assignment",
      {
        type: "assigned",
        topic_id: topic_id,
        post_id: target.is_a?(Post) && target.id,
        post_number: target.is_a?(Post) && target.post_number,
        assigned_type: assigned_to_type,
        assigned_to: serializer_class.new(assigned_to, scope: Guardian.new, root: false).as_json,
        assignment_note: note,
        assignment_status: status,
      },
      user_ids: allowed_user_ids,
    )
  end

  private

  def default_status
    self.status ||= Assignment.default_status if SiteSetting.enable_assign_status
  end

  def validate_status
    if SiteSetting.enable_assign_status && !Assignment.statuses.include?(status)
      errors.add(:status, :invalid)
    end
  end
end

# == Schema Information
#
# Table name: assignments
#
#  id                  :bigint           not null, primary key
#  active              :boolean          default(TRUE)
#  assigned_to_type    :string           not null
#  note                :string
#  status              :text
#  target_type         :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  assigned_by_user_id :integer          not null
#  assigned_to_id      :integer          not null
#  target_id           :integer          not null
#  topic_id            :integer          not null
#
# Indexes
#
#  index_assignments_on_active                               (active)
#  index_assignments_on_assigned_to_id_and_assigned_to_type  (assigned_to_id,assigned_to_type)
#  index_assignments_on_post_target                          (target_id,target_type) UNIQUE WHERE ((target_type)::text = 'Post'::text)
#  index_assignments_on_target                               (target_id,target_type)
#  index_assignments_on_topic_group                          (target_id,target_type) UNIQUE WHERE (((target_type)::text = 'Topic'::text) AND ((assigned_to_type)::text = 'Group'::text))
#  index_assignments_on_topic_id                             (topic_id)
#  unique_target_and_assigned                                (assigned_to_id,assigned_to_type,target_id,target_type) UNIQUE
#
