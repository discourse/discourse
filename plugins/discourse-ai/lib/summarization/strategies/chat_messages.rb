# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Strategies
      class ChatMessages < Base
        def type
          AiSummary.summary_types[:complete]
        end

        def highest_target_number
          nil # We don't persist so we can return nil.
        end

        def initialize(target, since)
          super(target)
          @since = since
        end

        def targets_data
          target
            .chat_messages
            .where("chat_messages.created_at > ?", since.hours.ago)
            .includes(:user)
            .order(created_at: :asc)
            .pluck(:id, :username_lower, :message, :updated_at)
            .map { { id: _1, poster: _2, text: _3, last_version_at: _4 } }
        end

        def as_llm_messages(contents)
          content_title = target.name
          input =
            contents.map { |item| "(#{item[:id]} #{item[:poster]} said: #{item[:text]} " }.join

          [{ type: :user, content: <<~TEXT.strip }]
            #{content_title.present? ? "These texts come from a chat channel called " + content_title + ".\n" : ""}
            
            Here are the texts, inside <input></input> XML tags:

            <input>
              #{input}
            </input>

            Generate a summary of the given chat messages.
          TEXT
        end

        private

        attr_reader :since
      end
    end
  end
end
