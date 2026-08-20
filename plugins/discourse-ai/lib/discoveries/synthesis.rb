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
      SOURCE_ONLY_RESPONSE_FORMAT = RESPONSE_FORMAT.first(2).freeze
      TITLELESS_SUMMARY_RESPONSE_FORMAT =
        RESPONSE_FORMAT.reject { |property| property["key"] == "title" }.freeze

      def initialize(user:, ai_agent:, llm_model:, cancel_manager: nil)
        @user = user
        @ai_agent = ai_agent
        @llm_model = llm_model
        @cancel_manager = cancel_manager
      end

      def call(
        query:,
        candidates:,
        show_summary: true,
        summary_detail: :balanced,
        related_count: DiscourseAi::Discoveries::MIN_RELATED_DISCUSSIONS
      )
        if candidates.empty?
          return Result.new(answerable: false, source_refs: [], title: "", answer: "")
        end
        related_count = normalized_related_count(related_count)
        show_title = show_summary && summary_detail.to_s != "quiet"

        context =
          DiscourseAi::Agents::BotContext.new(
            user: @user,
            messages: [
              {
                type: :user,
                content: input(query, candidates, show_summary:, summary_detail:, related_count:),
              },
            ],
            skip_show_thinking: true,
            feature_name: "discover",
            cancel_manager: @cancel_manager,
          )
        bot =
          DiscourseAi::Agents::Bot.as(
            Discourse.system_user,
            agent: synthesis_agent(show_summary:, show_title:, related_count:),
            model: @llm_model,
          )
        values = { answerable: nil, source_refs: nil, title: +"", answer: +"" }

        bot.reply(context) do |partial, _, type|
          next if type != :structured_output

          answerable = partial.read_buffered_property(:answerable)
          values[:answerable] = answerable if !answerable.nil?

          source_refs = partial.read_buffered_property(:source_refs)
          values[:source_refs] = source_refs if !source_refs.nil?

          if show_title
            title = partial.read_buffered_property(:title)
            values[:title] << title if title.present?
          end

          if show_summary
            answer_delta = partial.read_buffered_property(:answer)
            values[:answer] << answer_delta if !answer_delta.nil?
          end

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

      def synthesis_agent(show_summary:, show_title:, related_count:)
        response_format =
          if !show_summary
            SOURCE_ONLY_RESPONSE_FORMAT
          elsif !show_title
            TITLELESS_SUMMARY_RESPONSE_FORMAT
          else
            RESPONSE_FORMAT
          end.deep_dup
        response_format.find { |property| property["key"] == "source_refs" }[
          "max_items"
        ] = related_count

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

      def input(
        query,
        candidates,
        show_summary: true,
        summary_detail: :balanced,
        related_count: DiscourseAi::Discoveries::MIN_RELATED_DISCUSSIONS
      )
        JSON.generate(
          query:,
          preferences: {
            show_summary:,
            summary_detail:,
            related_count:,
          },
          candidates: candidates.map { |candidate| candidate_input(candidate) },
        )
      end

      def candidate_input(candidate)
        input = candidate.slice("source_ref", "title", "excerpt", "category").compact
        input["last_updated_at"] = candidate["post_updated_at"] if candidate["post_updated_at"]
        input
      end

      def normalized_related_count(related_count)
        related_count = related_count.to_i
        if related_count.between?(
             DiscourseAi::Discoveries::MIN_RELATED_DISCUSSIONS,
             DiscourseAi::Discoveries::MAX_RELATED_DISCUSSIONS,
           )
          return related_count
        end

        DiscourseAi::Discoveries::MIN_RELATED_DISCUSSIONS
      end
    end
  end
end
