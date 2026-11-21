# frozen_string_literal: true

class User::UpdateBotInteractivity
  include Service::Base

  params do
    attribute :user_id, :integer
    attribute :interactive_bot

    validates :user_id, presence: true

    validate do
      if [true, false, "true", "false"].exclude?(interactive_bot)
        errors.add(:interactive_bot, :inclusion)
      end
    end
  end

  model :user
  policy :can_update_bot_interactivity
  policy :site_not_archived

  transaction do
    step :update_interactivity
    only_if(:interactivity_changed) { step :log_interactivity_change }
  end

  private

  def fetch_user(params:)
    User.find_by(id: params.user_id)
  end

  def can_update_bot_interactivity(guardian:, user:)
    guardian.can_update_bot_interactivity?(user)
  end

  def site_not_archived
    !SiteSetting.site_archived
  end

  def update_interactivity(params:, user:)
    user.update!(interactive_bot: params.interactive_bot.in?([true, "true"]))
  end

  def interactivity_changed(user:)
    user.saved_change_to_interactive_bot?
  end

  def log_interactivity_change(user:, guardian:)
    StaffActionLogger.new(guardian.user).log_bot_interactivity_change(user)
  end
end
