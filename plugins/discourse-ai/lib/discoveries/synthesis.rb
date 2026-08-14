# frozen_string_literal: true

module DiscourseAi
  module Discoveries
    class Synthesis
      Result = Struct.new(:answerable, :source_refs, :title, :answer, keyword_init: true)
      RESPONSE_FORMAT = [
        { "key" => "answerable", "type" => "boolean" },
        {
          "key" => "source_refs",
          "type" => "array",
          "array_type" => "string",
          "max_items" => DiscourseAi::Discoveries::Retrieval::SELECTED_SOURCE_LIMIT,
        },
        { "key" => "title", "type" => "string" },
        { "key" => "answer", "type" => "string" },
      ].freeze

      def initialize(user:, ai_agent:, llm_model:, cancel_manager: nil)
        @user = user
        @ai_agent = ai_agent
        @llm_model = llm_model
        @cancel_manager = cancel_manager
      end

      def call(query:, candidates:)
        if candidates.empty?
          return Result.new(answerable: false, source_refs: [], title: "", answer: "")
        end

        context =
          DiscourseAi::Agents::BotContext.new(
            user: @user,
            messages: [{ type: :user, content: input(query, candidates) }],
            skip_show_thinking: true,
            feature_name: "discover",
            cancel_manager: @cancel_manager,
          )
        bot =
          DiscourseAi::Agents::Bot.as(
            Discourse.system_user,
            agent: synthesis_agent,
            model: @llm_model,
          )
        values = { answerable: nil, source_refs: nil, title: +"", answer: +"" }

        bot.reply(context) do |partial, _, type|
          next if type != :structured_output

          answerable = partial.read_buffered_property(:answerable)
          values[:answerable] = answerable if !answerable.nil?

          source_refs = partial.read_buffered_property(:source_refs)
          values[:source_refs] = source_refs if !source_refs.nil?

          title = partial.read_buffered_property(:title)
          values[:title] << title if title.present?

          answer_delta = partial.read_buffered_property(:answer)
          values[:answer] << answer_delta if answer_delta.present?

          yield values.deep_dup if block_given?
        end

        Result.new(
          answerable: values[:answerable] == true,
          source_refs: Array(values[:source_refs]),
          title: values[:title].to_s.strip,
          answer: values[:answer].strip,
        )
      end

      private

      def synthesis_agent
        response_format = RESPONSE_FORMAT

        Class
          .new(@ai_agent.class_instance) do
            define_method(:tools) { [] }
            define_method(:available_tools) { [] }
            define_method(:runtime_tools) { |**| [] }
            define_method(:native_tools) { [] }
            define_method(:required_tools) { [] }
            define_method(:force_tool_use) { [] }
            define_method(:forced_tool_count) { -1 }
            define_method(:response_format) { response_format }
          end
          .new
      end

      def input(query, candidates)
        JSON.generate(
          query:,
          candidates:
            candidates.map { |candidate| candidate.slice("source_ref", "title", "excerpt") },
        )
      end
    end
  end
end
