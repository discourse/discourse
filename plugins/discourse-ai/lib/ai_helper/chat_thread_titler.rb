# frozen_string_literal: true

module DiscourseAi
  module AiHelper
    class ChatThreadTitler
      def initialize(thread)
        @thread = thread
      end

      def suggested_title
        content = thread_content(@thread)
        return nil if content.blank?

        suggested_title = call_llm(content)
        cleanup(suggested_title)
      end

      def call_llm(thread_content)
        chat = "<input>\n#{thread_content}\n</input>"

        prompt =
          DiscourseAi::Completions::Prompt.new(
            <<~TEXT.strip,
            I want you to act as a title generator for chat between users. I will provide you with the chat transcription,
            and you will generate a single attention-grabbing title. Please keep the title concise and under 15 words
            and ensure that the meaning is maintained. The title will utilize the same language type of the chat.
            I want you to only reply the suggested title and nothing else, do not write explanations.
            You will find the chat between <input></input> XML tags. Return the suggested title between <title> tags.
          TEXT
            messages: [{ type: :user, content: chat, id: "User" }],
          )

        DiscourseAi::Completions::Llm.proxy(SiteSetting.ai_helper_model).generate(
          prompt,
          user: Discourse.system_user,
          stop_sequences: ["</input>"],
          feature_name: "chat_thread_title",
        )
      end

      def cleanup(title)
        (Nokogiri::HTML5.fragment(title).at("title")&.text || title)
          .split("\n")
          .first
          .then { _1.match?(/^("|')(.*)("|')$/) ? _1[1..-2] : _1 }
          .truncate(100, separator: " ")
      end

      def thread_content(thread)
        # TODO: Replace me by a proper API call
        thread
          .chat_messages
          .joins(:user)
          .pluck(:username, :message)
          .map { |username, message| "#{username}: #{message}" }
          .join("\n")
      end

      attr_reader :thread
    end
  end
end
