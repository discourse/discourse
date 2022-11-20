# frozen_string_literal: true

module ChatSystemHelpers
  def chat_system_bootstrap(user, channels_for_membership = [])
    # ensures we have one valid registered admin/user
    user.activate

    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:trust_level_1]

    channels_for_membership.each do |channel|
      membership = channel.add(user)
      if channel.chat_messages.any?
        membership.update!(last_read_message_id: channel.chat_messages.last.id)
      end
    end

    Group.refresh_automatic_groups!
  end
end

RSpec.configure do |config|
  config.include ChatSystemHelpers, type: :system
end
