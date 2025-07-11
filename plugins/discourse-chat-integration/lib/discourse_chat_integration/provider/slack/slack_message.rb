# frozen_string_literal: true

module DiscourseChatIntegration::Provider::SlackProvider
  class SlackMessage
    def initialize(raw_message, transcript)
      @raw = raw_message
      @transcript = transcript
    end

    def username
      if user
        user["_transcript_username"]
      elsif @raw.key?("username")
        # This is for bot messages
        @raw["username"].gsub(" ", "_")
      end
    end

    def avatar
      user["profile"]["image_24"] if user
    end

    def url
      channel_id = @transcript.channel_id
      ts = @raw["ts"].gsub(".", "")
      "https://slack.com/archives/#{channel_id}/p#{ts}"
    end

    def text
      text = @raw["text"].nil? ? "" : @raw["text"]

      pre = {}

      # Extract code blocks and replace with placeholder
      text =
        text.gsub(/```(.*?)```/m) do |match|
          key = "pre:" + SecureRandom.alphanumeric(50)
          pre[key] = HTMLEntities.new.decode $1
          "\n```\n#{key}\n```\n"
        end

      # # Extract inline code and replace with placeholder
      text =
        text.gsub(/(?<!`)`([^`]+?)`(?!`)/) do |match|
          key = "pre:" + SecureRandom.alphanumeric(50)
          pre[key] = HTMLEntities.new.decode $1
          "`#{key}`"
        end

      # Format links (don't worry about special cases @ # !)
      text =
        text.gsub(/<(.*?)>/) do |match|
          group = $1
          parts = group.split("|")
          link = parts[0].start_with?("@", "#", "!") ? nil : parts[0]
          text = parts.length > 1 ? parts[1] : parts[0]

          if parts[0].start_with?("@")
            user_id = parts[0][1..-1]
            if user = @transcript.users[user_id]
              user_name = user["_transcript_username"]
            else
              user_name = user_id
            end
            next "@#{user_name}"
          end

          if link.nil?
            text
          elsif link == text
            "<#{link}>"
          else
            "[#{text}](#{link})"
          end
        end

      # Add an extra * to each side for bold
      text = text.gsub(/\*.*?\*/) { |match| "*#{match}*" }

      # Add an extra ~ to each side for strikethrough
      text = text.gsub(/~.*?~/) { |match| "~#{match}~" }

      # Replace emoji - with _
      text = text.gsub(/:[a-z0-9_-]+:/) { |match| match.gsub("-") { "_" } }

      # Restore pre-formatted code block content
      pre.each { |key, value| text = text.gsub(key) { value } }

      text
    end

    def attachments_string
      string = ""
      string += "\n" if !attachments.empty?
      attachments.each { |attachment| string += " - #{attachment}\n" }
      string
    end

    def processed_text_with_attachments
      self.text + attachments_string
    end

    def raw_text
      raw_text = @raw["text"].nil? ? "" : @raw["text"]
      raw_text += attachments_string
      raw_text
    end

    def attachments
      attachments = []

      return attachments unless @raw.key?("attachments")

      @raw["attachments"].each do |attachment|
        next unless attachment.key?("fallback")
        attachments << attachment["fallback"]
      end

      attachments
    end

    def ts
      @raw["ts"]
    end

    private

    def user
      return nil unless user_id = @raw["user"]
      @transcript.users[user_id]
    end
  end
end
