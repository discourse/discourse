# frozen_string_literal: true

module DiscourseAi
  module Discoveries
    class Synthesis
      Result = Struct.new(:answerable, :source_refs, :title, :answer, keyword_init: true)
      PLACEHOLDER_ANSWERS = %w[true false null undefined none].freeze
      SOURCE_REFERENCE_PATTERN =
        /[ \t]*(?:\[\[source_\d+\]\]|\[source_\d+\](?:\([^)]+\))?|\(source_\d+\))(?:[ \t]*,[ \t]*(?:\[\[source_\d+\]\]|\[source_\d+\](?:\([^)]+\))?|\(source_\d+\)))*/i
      SOURCES_SECTION_PATTERN =
        /\n{2,}(?:\#{1,6}\s*)?(?:\*\*|__)?(?:sources|references)\s*:?(?:\*\*|__)?\s*\n.*\z/im

      def initialize(user:, ai_agent:, llm_model:, cancel_manager: nil)
        @user = user
        @ai_agent = ai_agent
        @llm_model = llm_model
        @cancel_manager = cancel_manager
      end

      def call(
        query:,
        candidates:,
        summary_detail: :balanced,
        related_count: DiscourseAi::Discoveries::MIN_RELATED_DISCUSSIONS
      )
        if candidates.empty?
          return Result.new(answerable: false, source_refs: [], title: "", answer: "")
        end
        related_count = normalized_related_count(related_count)

        context =
          DiscourseAi::Agents::BotContext.new(
            user: @user,
            messages: [
              { type: :user, content: input(query, candidates, summary_detail:, related_count:) },
            ],
            skip_show_thinking: true,
            feature_name: "discover",
            cancel_manager: @cancel_manager,
          )
        bot =
          DiscourseAi::Agents::Bot.as(
            Discourse.system_user,
            agent: synthesis_agent(summary_detail:),
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
          values[:answer] << answer_delta if !answer_delta.nil?

          if block_given?
            update = values.deep_dup
            update[:answer] = answer_without_source_references(update[:answer])
            yield update
          end
        end

        result =
          Result.new(
            answerable: values[:answerable] == true,
            source_refs: Array(values[:source_refs]),
            title: values[:title].to_s.strip,
            answer: answer_without_source_references(values[:answer]),
          )
        return empty_result if !result.answerable

        valid_result?(result, candidates:, related_count:) ? result : empty_result
      end

      def self.meaningful_answer?(answer)
        normalized = answer.to_s.squish.downcase
        normalized.present? &&
          PLACEHOLDER_ANSWERS.none? { |placeholder| placeholder.start_with?(normalized) } &&
          normalized.match?(/[[:alnum:]]/)
      end

      private

      def valid_result?(result, candidates:, related_count:)
        return false if result.source_refs.empty?
        return false if result.source_refs.uniq.length != result.source_refs.length
        return false if result.source_refs.length > related_count

        candidate_refs = candidates.pluck("source_ref")
        if result.source_refs.any? { |source_ref| !candidate_refs.include?(source_ref) }
          return false
        end
        return false if !self.class.meaningful_answer?(result.answer)

        true
      end

      def empty_result
        Result.new(answerable: false, source_refs: [], title: "", answer: "")
      end

      def synthesis_agent(summary_detail:)
        configured_agent = @ai_agent.class_instance.new
        system_prompt = [configured_agent.system_prompt, summary_instruction(summary_detail:)].join(
          "\n\n",
        )

        Class
          .new(DiscourseAi::Agents::Discover) do
            define_method(:system_prompt) { system_prompt }
            define_method(:temperature) { configured_agent.temperature }
            define_method(:top_p) { configured_agent.top_p }
            define_method(:thinking_effort) { configured_agent.thinking_effort }
          end
          .new
      end

      def summary_instruction(summary_detail:)
        detail_instruction =
          case summary_detail.to_s
          when "quiet"
            "For this request, write exactly one concise sentence with no title."
          when "detailed"
            "For this request, write two or three short paragraphs totaling 100 to 160 words. Separate paragraphs with a blank line. Do not combine them into one paragraph."
          else
            "For this request, write exactly one paragraph of 40 to 80 words."
          end

        "#{detail_instruction} Do not include source identifiers, citations, or a sources or references section. The selected discussions are shown separately."
      end

      def answer_without_source_references(answer)
        answer
          .to_s
          .sub(SOURCES_SECTION_PATTERN, "")
          .gsub(SOURCE_REFERENCE_PATTERN, "")
          .gsub(/[ \t]+([.,;:!?])/, '\\1')
          .strip
      end

      def input(
        query,
        candidates,
        summary_detail: :balanced,
        related_count: DiscourseAi::Discoveries::MIN_RELATED_DISCUSSIONS
      )
        JSON.generate(
          original_query: query,
          user_locale: @user.effective_locale,
          settings: {
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
