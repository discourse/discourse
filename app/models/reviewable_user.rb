# frozen_string_literal: true

class ReviewableUser < Reviewable

  def self.create_for(user)
    create(
      created_by_id: Discourse.system_user.id,
      target: user
    )
  end

  def build_actions(actions, guardian, args)
    return unless pending?

    if guardian.can_approve?(target) || args[:approved_by_invite]
      actions.add(:approve_user) do |a|
        a.icon = 'user-plus'
        a.label = "reviewables.actions.approve_user.title"
      end
    end

    reject = actions.add_bundle(
      'reject_user',
      icon: 'user-times',
      label: 'reviewables.actions.reject_user.title'
    )
    actions.add(:reject_user_delete, bundle: reject) do |a|
      a.icon = 'user-times'
      a.label = "reviewables.actions.reject_user.delete.title"
      a.description = "reviewables.actions.reject_user.delete.description"
    end
    actions.add(:reject_user_block, bundle: reject) do |a|
      a.icon = 'ban'
      a.label = "reviewables.actions.reject_user.block.title"
      a.description = "reviewables.actions.reject_user.block.description"
    end
  end

  def perform_approve_user(performed_by, args)
    ReviewableUser.set_approved_fields!(target, performed_by)
    target.save!

    DiscourseEvent.trigger(:user_approved, target)

    if args[:send_email] != false && SiteSetting.must_approve_users?
      Jobs.enqueue(
        :critical_user_email,
        type: :signup_after_approval,
        user_id: target.id
      )
    end
    StaffActionLogger.new(performed_by).log_user_approve(target)

    create_result(:success, :approved)
  end

  def perform_reject_user_delete(performed_by, args)
    # We'll delete the user if we can
    if target.present?
      destroyer = UserDestroyer.new(performed_by)

      if reviewable_scores.any? { |rs| rs.reason == 'suspect_user' }
        DiscourseEvent.trigger(:suspect_user_deleted, target)
      end

      begin
        delete_args = {}
        delete_args[:block_ip] = true if args[:block_ip]
        delete_args[:block_email] = true if args[:block_email]

        destroyer.destroy(target, delete_args)
      rescue UserDestroyer::PostsExistError
        # If a user has posts, we won't delete them to preserve their content.
        # However the reviable record will be "rejected" and they will remain
        # unapproved in the database. A staff member can still approve them
        # via the admin.
      end
    end

    create_result(:success, :rejected)
  end

  def perform_reject_user_block(performed_by, args)
    args[:block_email] = true
    args[:block_ip] = true
    perform_reject_user_delete(performed_by, args)
  end

  # Update's the user's fields for approval but does not save. This
  # can be used when generating a new user that is approved on create
  def self.set_approved_fields!(user, approved_by)
    user.approved = true
    user.approved_by ||= approved_by
    user.approved_at ||= Time.zone.now
  end
end

# == Schema Information
#
# Table name: reviewables
#
#  id                      :bigint           not null, primary key
#  type                    :string           not null
#  status                  :integer          default(0), not null
#  created_by_id           :integer          not null
#  reviewable_by_moderator :boolean          default(FALSE), not null
#  reviewable_by_group_id  :integer
#  category_id             :integer
#  topic_id                :integer
#  score                   :float            default(0.0), not null
#  potential_spam          :boolean          default(FALSE), not null
#  target_id               :integer
#  target_type             :string
#  target_created_by_id    :integer
#  payload                 :json
#  version                 :integer          default(0), not null
#  latest_score            :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
# Indexes
#
#  index_reviewables_on_reviewable_by_group_id                 (reviewable_by_group_id)
#  index_reviewables_on_status_and_created_at                  (status,created_at)
#  index_reviewables_on_status_and_score                       (status,score)
#  index_reviewables_on_status_and_type                        (status,type)
#  index_reviewables_on_topic_id_and_status_and_created_by_id  (topic_id,status,created_by_id)
#  index_reviewables_on_type_and_target_id                     (type,target_id) UNIQUE
#
