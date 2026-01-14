# frozen_string_literal: true

class ReviewableUser < Reviewable
  include ReviewableActionBuilder

  def self.create_for(user)
    create(created_by_id: Discourse.system_user.id, target: user)
  end

  def self.additional_args(params)
    { reject_reason: params[:reject_reason], send_email: params[:send_email] != "false" }
  end

  def build_legacy_combined_actions(actions, guardian, args)
    if status == "rejected" && !payload["scrubbed_by"]
      build_action(actions, :scrub, client_action: "scrub")
    end
    if status == "pending"
      if is_a_suspect_user?
        confirm_spam_bundle =
          actions.add_bundle(
            "#{id}-confirm-spam",
            icon: "user-xmark",
            label: "reviewables.actions.confirm_spam.title",
          )
        delete_user_actions(actions, confirm_spam_bundle, require_reject_reason: false)

        if guardian.can_approve?(target)
          actions.add(:approve_user, bundle: nil) do |a|
            a.icon = "user-plus"
            a.label = "reviewables.actions.not_spam.title"
            a.description = "reviewables.actions.not_spam.description"
            a.completed_message = "reviewables.actions.approve_user.complete"
          end
        end
      else
        if guardian.can_approve?(target)
          actions.add(:approve_user, bundle: nil) do |a|
            a.icon = "user-plus"
            a.label = "reviewables.actions.approve_user.title"
          end
        end
        delete_user_actions(actions, require_reject_reason: true)
      end
    end
  end

  def build_actions(actions, guardian, args)
    return if approved?
    super
  end

  # TODO (reviewable-refresh): Move to build_actions when fully migrated to new UI
  def build_new_separated_actions
    bundle_actions = {}
    if status == "pending"
      bundle_actions[:approve_user] = {} if target_user && !target_user.approved? &&
        guardian.can_approve?(target_user)

      if @guardian.can_delete_user?(target_user)
        bundle_actions[:delete_user] = {}
        bundle_actions[:delete_user_block] = {}
      end
    end
    if status == "rejected" && !payload["scrubbed_by"]
      bundle_actions[:scrub] = { client_action: "scrub" }
    end

    build_bundle(
      "#{id}-user-actions",
      "reviewables.actions.user_actions.bundle_title",
      bundle_actions,
      source: "core",
    )
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

  def scrub(reason, guardian)
    self.class.transaction do
      scrubbed_at = Time.zone.now
      # We need to scrub the UserHistory record for when this user was deleted, as well as this reviewable's payload
      UserHistory
        .where(action: UserHistory.actions[:delete_user])
        .where("details LIKE :query", query: "%\nusername: #{payload["username"]}\n%")
        .where(created_at: (updated_at - 10.minutes)..(updated_at + 10.minutes))
        .update_all(
          details:
            I18n.t(
              "user.destroy_reasons.reviewable_details_scrubbed",
              staff: guardian.current_user.username,
              reason: reason,
              timestamp: scrubbed_at,
            ),
          ip_address: nil,
        )

      self.payload = {
        scrubbed_by: guardian.current_user.username,
        scrubbed_reason: reason,
        scrubbed_at:,
      }
      self.save!

      result = create_result(:success)

      notify_users(result, guardian)

      result
    end
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
        delete_args[:from_reviewable] = true

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
#  type_source             :string           default("unknown"), not null
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
