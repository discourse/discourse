# frozen_string_literal: true

class Chat::Api::SummariesController < Chat::ApiController
  VALID_SINCE_VALUES = [1, 3, 6, 12, 24, 72, 168]

  def get_summary
    since = params[:since].to_i
    raise Discourse::InvalidParameters.new(:since) if !VALID_SINCE_VALUES.include?(since)

    channel = Chat::Channel.find(params[:channel_id])
    guardian.ensure_can_join_chat_channel!(channel)

    strategy = Summarization::Base.selected_strategy
    raise Discourse::NotFound.new unless strategy
    raise Discourse::InvalidAccess unless strategy.can_request_summaries?(current_user)

    RateLimiter.new(current_user, "channel_summary", 6, 5.minutes).performed!

    hijack do
      content =
        channel
          .chat_messages
          .where("chat_messages.created_at > ?", since.hours.ago)
          .includes(:user)
          .order(created_at: :asc)
          .pluck(:username_lower, :message)
          .map { "#{_1}: #{_2}" }
          .join("\n")

      render json: { summary: strategy.summarize(content).dig(:summary) }
    end
  end
end
