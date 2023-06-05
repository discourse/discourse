# frozen_string_literal: true

class Chat::Api::SummariesController < Chat::ApiController
  def last_visit
    raise Discourse::InvalidParameters.new(:message_id) unless params[:message_id]
    channel = Chat::Channel.find(params[:channel_id])
    guardian.ensure_can_preview_chat_channel!(channel)
    strategy = Summarization::Base.selected_strategy
    raise Discourse::NotFound.new unless strategy

    raise Discourse::InvalidAccess unless strategy.can_request_summaries?(current_user)

    RateLimiter.new(current_user, "channel_summary", 6, 5.minutes).performed!

    hijack do
      content =
        channel
          .chat_messages
          .where("chat_messages.id > ?", params[:message_id])
          .includes(:user)
          .order(created_at: :asc)
          .limit(100)
          .pluck(:username_lower, :message)
          .map { "#{_1}: #{_2}" }
          .join("\n")

      render json: { summary: strategy.summarize(content) }
    end
  end
end
