# frozen_string_literal: true

module DiscourseAi
  module Summarization
    class ChatSummaryController < ::Chat::ApiController
      requires_plugin ::DiscourseAi::PLUGIN_NAME
      requires_plugin ::Chat::PLUGIN_NAME

      VALID_SINCE_VALUES = [1, 3, 6, 12, 24, 72, 168]

      def show
        since = params[:since].to_i
        raise Discourse::InvalidParameters.new(:since) if !VALID_SINCE_VALUES.include?(since)

        channel = ::Chat::Channel.find(params[:channel_id])
        guardian.ensure_can_join_chat_channel!(channel)

        summarizer = DiscourseAi::Summarization.chat_channel_summary(channel, since)
        raise Discourse::NotFound.new unless summarizer

        guardian.ensure_can_request_summary!

        RateLimiter.new(current_user, "channel_summary", 6, 5.minutes).performed!

        hijack do
          strategy = DiscourseAi::Summarization::Strategies::ChatMessages.new(channel, since)

          summarized_text =
            if strategy.targets_data.empty?
              I18n.t("discourse_ai.summarization.chat.no_targets")
            else
              summarizer.summarize(current_user)&.summarized_text
            end

          render json: { summary: summarized_text }
        end
      end
    end
  end
end
