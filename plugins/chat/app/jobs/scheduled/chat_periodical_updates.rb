# frozen_string_literal: true

module Jobs
  class ChatPeriodicalUpdates < ::Jobs::Scheduled
    every 15.minutes

    def execute(args = nil)
      # TODO: Add rebaking of old messages (baked_version <
      # ChatMessage::BAKED_VERSION or baked_version IS NULL)
      ChatChannel.ensure_consistency!
      nil
    end
  end
end
