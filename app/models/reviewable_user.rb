require_dependency 'reviewable'

class ReviewableUser < Reviewable
  def self.create_for(user)
    create(
      created_by_id: Discourse.system_user.id,
      target: user
    )
  end

  def build_actions(actions, guardian, args)
    return unless pending?

    actions.add(:approve) if guardian.can_approve?(target) || args[:approved_by_invite]
    actions.add(:reject) if guardian.can_delete_user?(target)
  end

  def perform_approve(performed_by, args)
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

  def perform_reject(performed_by, args)
    destroyer = UserDestroyer.new(performed_by) unless args[:skip_delete]

    # If a user has posts, we won't delete them to preserve their content.
    # However the reviable record will be "rejected" and they will remain
    # unapproved in the database. A staff member can still approve them
    # via the admin.
    destroyer.destroy(target) rescue UserDestroyer::PostsExistError

    create_result(:success, :rejected)
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
#  id                      :bigint(8)        not null, primary key
#  type                    :string           not null
#  status                  :integer          default(0), not null
#  created_by_id           :integer          not null
#  reviewable_by_moderator :boolean          default(FALSE), not null
#  reviewable_by_group_id  :integer
#  claimed_by_id           :integer
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
#  index_reviewables_on_status_and_created_at  (status,created_at)
#  index_reviewables_on_status_and_score       (status,score)
#  index_reviewables_on_status_and_type        (status,type)
#  index_reviewables_on_type_and_target_id     (type,target_id) UNIQUE
#
