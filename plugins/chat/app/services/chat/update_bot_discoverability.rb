# frozen_string_literal: true

class Chat::UpdateBotDiscoverability
  include Service::Base

  policy :can_manage_bots

  params do
    attribute :user_id, :integer
    attribute :discoverable, :boolean

    validates :user_id, presence: true
    validates :discoverable, inclusion: { in: [true, false] }
  end

  model :bot

  transaction do
    only_if(:discoverability_changes) do
      only_if(:becomes_discoverable) { step :list_bot }
      only_if(:stops_being_discoverable) { step :unlist_bot }
      step :log_discoverability_change
    end
  end

  private

  def can_manage_bots(guardian:)
    guardian.is_admin?
  end

  def fetch_bot(params:)
    User.bot_users.where.not(id: Discourse::SYSTEM_USER_ID).find_by(id: params.user_id)
  end

  def discoverability_changes(bot:, params:)
    bot.chat_discoverable_bot.present? != params.discoverable
  end

  def becomes_discoverable(params:)
    params.discoverable
  end

  def stops_being_discoverable(params:)
    !params.discoverable
  end

  def list_bot(bot:)
    Chat::DiscoverableBot.create_or_find_by!(user: bot)
  end

  def unlist_bot(bot:)
    bot.chat_discoverable_bot.destroy!
  end

  def log_discoverability_change(bot:, params:, guardian:)
    StaffActionLogger.new(guardian.user).log_custom(
      "chat_bot_discoverability_change",
      subject: bot.username,
      previous_value: (!params.discoverable).to_s,
      new_value: params.discoverable.to_s,
    )
  end
end
