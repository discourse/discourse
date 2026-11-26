# frozen_string_literal: true

class User::UpdateBotInteractivity
  include Service::Base

  params do
    attribute :user_id, :integer
    attribute :interactive_bot, :boolean

    validates :user_id, presence: true

    validate do
      value = raw_attributes["interactive_bot"]
      unless [true, false, 1, 0, *%w[1 0 true false on off]].any? { |allowed| allowed.eql?(value) }
        errors.add(:interactive_bot, :inclusion)
      end
    end
  end

  model :user
  policy :can_update_bot_interactivity
  policy :site_not_archived

  transaction do
    step :lock_user
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

  def lock_user(user:)
    user.lock!
  end

  def update_interactivity(params:, user:)
    user.update!(interactive_bot: params.interactive_bot)
  end

  def interactivity_changed(user:)
    user.saved_change_to_interactive_bot?
  end

  def log_interactivity_change(user:, guardian:)
    StaffActionLogger.new(guardian.user).log_bot_interactivity_change(user)
  end
end
