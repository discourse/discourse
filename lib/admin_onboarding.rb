# frozen_string_literal: true

# The setup checklist a new site shows its owner, the first human admin, for
# their first few days.
module AdminOnboarding
  STEP_COMPLETED_CHANNEL = "/admin-onboarding/step-completed"
  STEPS = [*UserHistory::ADMIN_ONBOARDING_STEPS, UserHistory::ADMIN_ONBOARDING_AGENT_STEP].freeze

  def self.shown_to?(user)
    return false if !SiteSetting.enable_site_owner_onboarding || !user&.admin?

    owner_id, owner_created_at = owner
    owner_id == user.id && open_for?(owner_created_at)
  end

  # Records the first time any admin completes a step, wherever they did it, and
  # ticks it off in the owner's checklist. Nothing is recorded once the owner
  # stops seeing the checklist, so the onboarding stats only cover onboarding.
  def self.complete_step(step, user)
    raise ArgumentError, "unknown admin onboarding step: #{step}" if STEPS.exclude?(step)
    return if !SiteSetting.enable_site_owner_onboarding || !user&.admin? || !user.human?

    owner_id, owner_created_at = owner
    return if owner_id.nil? || !open_for?(owner_created_at)

    completions =
      UserHistory.where(
        action: UserHistory.actions[:admin_onboarding_step_completed],
        subject: step,
      )
    return if completions.exists?

    StaffActionLogger.new(user).log_admin_onboarding_step_completed(step)
    DB.after_commit { MessageBus.publish(STEP_COMPLETED_CHANNEL, { step: }, user_ids: [owner_id]) }
  end

  def self.owner
    User.where(admin: true).human_users.order(:id).pick(:id, :created_at)
  end
  private_class_method :owner

  def self.open_for?(owner_created_at)
    owner_created_at.after?(SiteSetting.site_owner_onboarding_max_days.days.ago)
  end
  private_class_method :open_for?
end
