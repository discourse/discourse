# frozen_string_literal: true

module Chat
  class MessageStreamer
    def initialize(message, channel, user, bot_mention)
      @message = message
      @channel = channel
      @user = user
      @bot_mention = bot_mention
    end

    def stream_message
      if @bot_mention.length > 1
        Chat::Publisher.too_many_bot_mentions(@user.id, @message)
      else
        bot = User.find_by(username: @bot_mention.first)
        return unless bot.present?

        response = ""

        message =
          Chat::MessageCreator.create(
            chat_channel: @channel,
            user: bot,
            in_reply_to_id: @message.id,
            content: " ",
            streaming: true,
          ).chat_message

        get_reply_stream(message) do |chunk|
          next unless message.reload.streaming

          response += " #{chunk[:data]}"

          publish_response_update(bot, message, response)
        end

        publish_streaming_edit(message)
      end
    end

    def get_reply_stream(message)
      # Mock response
      rand(10..15).times do
        chunk = { data: ("a".."z").to_a.shuffle[0, rand(1..8)].join }
        sleep 1

        yield chunk
      end
    end

    def publish_response_update(bot, message, response)
      Chat::MessageUpdater.update(
        guardian: bot.guardian,
        chat_message: message,
        new_content: response,
        streaming: true,
      )
    end

    def publish_streaming_edit(message)
      Chat::Publisher.publish_edit!(@channel, message, streaming: false) if message.reload.streaming
    end
  end
end
