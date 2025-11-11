# frozen_string_literal: true

module DiscourseAi
  module Personas
    class QuestionConsolidator
      attr_reader :llm, :messages, :user, :max_tokens

      def self.consolidate_question(llm, messages, user)
        new(llm, messages, user).consolidate_question
      end

      def initialize(llm, messages, user)
        @llm = llm
        @messages = messages
        @user = user
        @max_tokens = 2048
      end

      def consolidate_question
        @llm.generate(revised_prompt, user: @user, feature_name: "question_consolidator")
      end

      def revised_prompt
        max_tokens_per_model = @max_tokens / 5

        conversation_snippet = []
        tokens = 0

        messages.reverse_each do |message|
          # skip tool calls
          next if message[:type] != :user && message[:type] != :model

          row = +""
          row << ((message[:type] == :user) ? "user" : "model")

          content = DiscourseAi::Completions::Prompt.text_only(message)
          current_tokens = @llm.tokenizer.tokenize(content).length

          allowed_tokens = @max_tokens - tokens
          allowed_tokens = [allowed_tokens, max_tokens_per_model].min if message[:type] == :model

          truncated_content = content

          if current_tokens > allowed_tokens
            truncated_content =
              @llm.tokenizer.truncate(
                content,
                allowed_tokens,
                strict: SiteSetting.ai_strict_token_counting,
              )
            current_tokens = allowed_tokens
          end

          row << ": #{truncated_content}"
          tokens += current_tokens
          conversation_snippet << row

          break if tokens >= @max_tokens
        end

        history = conversation_snippet.reverse.join("\n")

        system_message = <<~TEXT
          You are Question Consolidation Bot: an AI assistant tasked with consolidating a user's latest question into a self-contained, context-rich question.

          - Your output will be used to query a vector database. DO NOT include superflous text such as "here is your consolidated question:".
          - You interact with an API endpoint, not a user, you must never produce denials, nor conversations directed towards a non-existent user.
          - You only produce automated responses to input, where a response is a consolidated question without further discussion.
          - You only ever reply with consolidated questions. You never try to answer user queries.

          If for any reason there is no discernable question (Eg: thank you, or good job) reply with the text NO_QUESTION.
        TEXT

        message = <<~TEXT
          Given the following conversation snippet, craft a self-contained context-rich question (if there is no question reply with NO_QUESTION):

          {{{
          #{history}
          }}}

          Only ever reply with a consolidated question. Do not try to answer user queries.
        TEXT

        response =
          DiscourseAi::Completions::Prompt.new(
            system_message,
            messages: [{ type: :user, content: message }],
          )

        if response == "NO_QUESTION"
          nil
        else
          response
        end
      end
    end
  end
end
