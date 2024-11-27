# frozen_string_literal: true

class ReviewableUser < Reviewable
  def self.create_for(user)
    create(created_by_id: Discourse.system_user.id, target: user)
  end

  def self.additional_args(params)
    { reject_reason: params[:reject_reason], send_email: params[:send_email] != "false" }
  end

  def build_actions(actions, guardian, args)
    return unless pending?

    if guardian.can_approve?(target)
      actions.add(:approve_user) do |a|
        a.icon = "user-plus"
        a.label = "reviewables.actions.approve_user.title"
      end
    end

    delete_user_actions(actions, require_reject_reason: !is_a_suspect_user?)
  end

  def perform_approve_user(performed_by, args)
    ReviewableUser.set_approved_fields!(target, performed_by)
    target.save!

    DiscourseEvent.trigger(:user_approved, target)

    if args[:send_email] != false && SiteSetting.must_approve_users?
      Jobs.enqueue(:critical_user_email, type: "signup_after_approval", user_id: target.id)
    end
    StaffActionLogger.new(performed_by).log_user_approve(target)

    create_result(:success, :approved)
  end

  def perform_delete_user(performed_by, args)
    # We'll delete the user if we can
    if target.present?
      destroyer = UserDestroyer.new(performed_by)

      DiscourseEvent.trigger(:suspect_user_deleted, target) if is_a_suspect_user?

      begin
        self.reject_reason = args[:reject_reason]

        # Without this, we end up sending the email even if this reject_reason is too long.
        self.validate!

        if args[:send_email] && SiteSetting.must_approve_users?
          # Execute job instead of enqueue because user has to exists to send email
          Jobs::CriticalUserEmail.new.execute(
            { type: :signup_after_reject, user_id: target.id, reject_reason: self.reject_reason },
          )
        end

        delete_args = {}
        delete_args[:block_ip] = true if args[:block_ip]
        delete_args[:block_email] = true if args[:block_email]
        delete_args[:context] = if performed_by.id == Discourse.system_user.id
          I18n.t("user.destroy_reasons.reviewable_reject_auto")
        else
          I18n.t("user.destroy_reasons.reviewable_reject")
        end

        destroyer.destroy(target, delete_args)
      rescue UserDestroyer::PostsExistError, Discourse::InvalidAccess
        # If a user has posts or user is an admin, we won't delete them to preserve their content.
        # However the reviewable record will be "rejected" and they will remain
        # unapproved in the database. A staff member can still approve them
        # via the admin.
      end
    end

    create_result(:success, :rejected)
  end

  def perform_delete_user_block(performed_by, args)
    args[:block_email] = true
    args[:block_ip] = true
    perform_delete_user(performed_by, args)
  end

  # Update's the user's fields for approval but does not save. This
  # can be used when generating a new user that is approved on create
  def self.set_approved_fields!(user, approved_by)
    user.approved = true
    user.approved_by ||= approved_by
    user.approved_at ||= Time.zone.now
  end

  def is_a_suspect_user?
    reviewable_scores.any? { |rs| rs.reason == "suspect_user" }
  end
end

# == Schema Information
#
# Table name: reviewables
#
#  id                      :bigint           not null, primary key
#  type                    :string           not null
#  status                  :integer          default("pending"), not null
#  created_by_id           :integer          not null
#  reviewable_by_moderator :boolean          default(FALSE), not null
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
#  force_review            :boolean          default(FALSE), not null
#  reject_reason           :text
#  potentially_illegal     :boolean          default(FALSE)
#
# Indexes
#
#  idx_reviewables_score_desc_created_at_desc                  (score,created_at)
#  index_reviewables_on_reviewable_by_group_id                 (reviewable_by_group_id)
#  index_reviewables_on_status_and_created_at                  (status,created_at)
#  index_reviewables_on_status_and_score                       (status,score)
#  index_reviewables_on_status_and_type                        (status,type)
#  index_reviewables_on_target_id_where_post_type_eq_post      (target_id) WHERE ((target_type)::text = 'Post'::text)
#  index_reviewables_on_topic_id_and_status_and_created_by_id  (topic_id,status,created_by_id)
#  index_reviewables_on_type_and_target_id                     (type,target_id) UNIQUE
#
