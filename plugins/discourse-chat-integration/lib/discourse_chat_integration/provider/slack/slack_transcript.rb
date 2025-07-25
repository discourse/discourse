# frozen_string_literal: true

module DiscourseChatIntegration::Provider::SlackProvider
  class SlackTranscript
    class UserFetchError < RuntimeError
    end

    attr_reader :users, :channel_id, :messages

    def initialize(channel_name:, channel_id:, requested_thread_ts: nil)
      @channel_name = channel_name
      @channel_id = channel_id
      @requested_thread_ts = requested_thread_ts

      @first_message_index = 0
      @last_message_index = -1 # We can use negative array indicies to select the last message - fancy!
    end

    def set_first_message_by_ts(ts)
      message_index = @messages.find_index { |m| m.ts == ts }
      @first_message_index = message_index if message_index
    end

    def set_last_message_by_ts(ts)
      message_index = @messages.find_index { |m| m.ts == ts }
      @last_message_index = message_index if message_index
    end

    def set_first_message_by_index(val)
      @first_message_index = val if @messages[val]
    end

    def set_last_message_by_index(val)
      @last_message_index = val if @messages[val]
    end

    # Apply a heuristic to decide which is the first message in the current conversation
    def guess_first_message(skip_messages: 5) # Can skip the last n messages
      return true if @requested_thread_ts # Always start thread on first message
      return false if @messages.blank? || @messages.size < skip_messages

      possible_first_messages = @messages[0..-skip_messages]

      # Work through the messages in order. If a gap is found, this could be the first message
      new_first_message_index = nil
      previous_message_ts = @messages[-skip_messages].ts.split(".").first.to_i
      possible_first_messages.each_with_index do |message, index|
        # Calculate the time since the last message
        this_ts = message.ts.split(".").first.to_i
        time_since_previous_message = this_ts - previous_message_ts

        # If greater than 3 minutes, this could be the first message
        new_first_message_index = index if time_since_previous_message > 3.minutes

        previous_message_ts = this_ts
      end

      if new_first_message_index
        @first_message_index = new_first_message_index
        true
      else
        false
      end
    end

    def first_message
      @messages[@first_message_index]
    end

    def last_message
      @messages[@last_message_index]
    end

    # These two methods convert potentially negative array indices into positive ones
    def first_message_number
      @first_message_index < 0 ? @messages.length + @first_message_index : @first_message_index
    end
    def last_message_number
      @last_message_index < 0 ? @messages.length + @last_message_index : @last_message_index
    end

    def build_transcript
      post_content = +""
      post_content << "[quote]\n" if SiteSetting.chat_integration_slack_transcript_quote
      post_content << "[**#{I18n.t("chat_integration.provider.slack.transcript.view_on_slack", name: @channel_name)}**](#{first_message.url})\n"

      all_avatars = {}

      last_username = ""

      transcript_messages = @messages[@first_message_index..@last_message_index]

      transcript_messages.each do |m|
        same_user = m.username == last_username
        last_username = m.username

        unless same_user
          if avatar = m.avatar
            all_avatars[m.username] ||= avatar
          end

          post_content << "\n"
          post_content << "![#{m.username}] " if m.avatar
          post_content << "**@#{m.username}:** "
        end

        post_content << m.text

        m.attachments.each { |attachment| post_content << "\n> #{attachment}\n" }

        post_content << "\n"
      end

      post_content << "[/quote]" if SiteSetting.chat_integration_slack_transcript_quote
      post_content << "\n\n"

      all_avatars.each { |username, url| post_content << "[#{username}]: #{url}\n" }

      if not @requested_thread_ts.nil?
        post_content << "<!--SLACK_CHANNEL_ID=#{@channel_name};SLACK_TS=#{@requested_thread_ts}-->"
      end

      post_content
    end

    def build_modal_ui
      data = {
        type: "modal",
        title: {
          type: "plain_text",
          text: I18n.t("chat_integration.provider.slack.transcript.modal_title"),
        },
        blocks: [
          {
            type: "section",
            text: {
              type: "mrkdwn",
              text: I18n.t("chat_integration.provider.slack.transcript.modal_description"),
            },
          },
        ],
      }

      if @messages
        post_content = build_transcript
        secret = DiscourseChatIntegration::Helper.save_transcript(post_content)
        link = "#{Discourse.base_url}/chat-transcript/#{secret}"

        data[:blocks] << {
          type: "section",
          text: {
            type: "mrkdwn",
            text:
              ":writing_hand: *#{I18n.t("chat_integration.provider.slack.transcript.transcript_ready")}*",
          },
          accessory: {
            type: "button",
            text: {
              type: "plain_text",
              text: I18n.t("chat_integration.provider.slack.transcript.continue_on_discourse"),
              emoji: true,
            },
            style: "primary",
            url: link,
            action_id: "null_action",
          },
        }
      else
        data[:blocks] << {
          type: "section",
          text: {
            type: "mrkdwn",
            text: ":writing_hand: #{I18n.t("chat_integration.provider.slack.transcript.loading")}",
          },
        }
      end

      data
    end

    def build_slack_ui
      post_content = build_transcript
      secret = DiscourseChatIntegration::Helper.save_transcript(post_content)
      link = "#{Discourse.base_url}/chat-transcript/#{secret}"

      if @requested_thread_ts
        return(
          {
            text:
              "<#{link}|#{I18n.t("chat_integration.provider.slack.transcript.post_to_discourse")}>",
          }
        )
      end

      {
        text: "<#{link}|#{I18n.t("chat_integration.provider.slack.transcript.post_to_discourse")}>",
        attachments: [
          {
            pretext:
              I18n.t(
                "chat_integration.provider.slack.transcript.first_message_pretext",
                n: @messages.length - first_message_number,
              ),
            fallback: "#{first_message.username} - #{first_message.raw_text}",
            color: "#007AB8",
            author_name: first_message.username,
            author_icon: first_message.avatar,
            text: first_message.raw_text,
            footer:
              I18n.t("chat_integration.provider.slack.transcript.posted_in", name: @channel_name),
            ts: first_message.ts,
            callback_id: last_message.ts,
            actions: [
              {
                name: "first_message",
                text: I18n.t("chat_integration.provider.slack.transcript.change_first_message"),
                type: "select",
                options:
                  first_message_options =
                    @messages[[(first_message_number - 20), 0].max..last_message_number].map do |m|
                      { text: "#{m.username}: #{m.processed_text_with_attachments}", value: m.ts }
                    end,
              },
            ],
          },
          {
            pretext:
              I18n.t(
                "chat_integration.provider.slack.transcript.last_message_pretext",
                n: @messages.length - last_message_number,
              ),
            fallback: "#{last_message.username} - #{last_message.raw_text}",
            color: "#007AB8",
            author_name: last_message.username,
            author_icon: last_message.avatar,
            text: last_message.raw_text,
            footer:
              I18n.t("chat_integration.provider.slack.transcript.posted_in", name: @channel_name),
            ts: last_message.ts,
            callback_id: first_message.ts,
            actions: [
              {
                name: "last_message",
                text: I18n.t("chat_integration.provider.slack.transcript.change_last_message"),
                type: "select",
                options:
                  @messages[first_message_number..(last_message_number + 20)].map do |m|
                    { text: "#{m.username}: #{m.processed_text_with_attachments}", value: m.ts }
                  end,
              },
            ],
          },
        ],
      }
    end

    def load_user_data
      key =
        "slack_user_info_#{Digest::SHA1.hexdigest(SiteSetting.chat_integration_slack_access_token)}"
      @users = Discourse.cache.fetch(key, expires_in: 10.minutes) { fetch_user_data }
      true
    rescue UserFetchError
      false
    end

    def fetch_user_data
      http = ::DiscourseChatIntegration::Provider::SlackProvider.slack_api_http

      cursor = nil
      req = Net::HTTP::Post.new(URI("https://slack.com/api/users.list"))

      users = {}
      loop do
        break if cursor == ""
        req.set_form_data(
          token: SiteSetting.chat_integration_slack_access_token,
          limit: 200,
          cursor: cursor,
        )
        response = http.request(req)
        raise UserFetchError.new unless response.kind_of? Net::HTTPSuccess
        json = JSON.parse(response.body)
        raise UserFetchError.new unless json["ok"]
        cursor = json["response_metadata"]["next_cursor"]
        json["members"].each do |user|
          # Slack uses display_name and falls back to real_name if it is not set
          if user["profile"]["display_name"].blank?
            user["_transcript_username"] = user["profile"]["real_name"]
          else
            user["_transcript_username"] = user["profile"]["display_name"]
          end
          user["_transcript_username"] = user["_transcript_username"].gsub(" ", "_")
          users[user["id"]] = user
        end
      end
      users
    end

    def load_chat_history(count: 500)
      http = DiscourseChatIntegration::Provider::SlackProvider.slack_api_http

      endpoint = @requested_thread_ts ? "replies" : "history"

      req = Net::HTTP::Post.new(URI("https://slack.com/api/conversations.#{endpoint}"))

      data = {
        token: SiteSetting.chat_integration_slack_access_token,
        channel: @channel_id,
        limit: count,
      }

      data[:ts] = @requested_thread_ts if @requested_thread_ts

      req.set_form_data(data)
      response = http.request(req)
      return false unless response.kind_of? Net::HTTPSuccess
      json = JSON.parse(response.body)
      return false unless json["ok"]

      raw_messages = json["messages"]
      raw_messages = raw_messages.reverse unless @requested_thread_ts

      # Build some message objects
      @messages = []
      raw_messages.each_with_index do |message, index|
        # Only load messages
        next unless message["type"] == "message"

        # Don't load responses to threads unless specifically requested (if ts==thread_ts then it's the thread parent)
        if !@requested_thread_ts && message["thread_ts"] && message["thread_ts"] != message["ts"]
          next
        end

        this_message = SlackMessage.new(message, self)
        @messages << this_message
      end
    end
  end
end
