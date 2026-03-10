# frozen_string_literal: true

module Jobs
  class StreamDiscordReply < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      interaction = args[:interaction]

      return unless SiteSetting.ai_discord_search_enabled

      if SiteSetting.ai_discord_search_mode == "agent"
        DiscourseAi::Discord::Bot::AgentReplier.new(interaction).handle_interaction!
      else
        DiscourseAi::Discord::Bot::Search.new(interaction).handle_interaction!
      end
    end
  end
end
