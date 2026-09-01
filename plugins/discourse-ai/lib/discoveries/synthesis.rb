# frozen_string_literal: true

module DiscourseAi
  module Discoveries
    class Synthesis
      Result =
        Struct.new(:answerable, :source_refs, :title, :answer, :follow_up, keyword_init: true)
      PLACEHOLDER_ANSWERS = %w[true false null undefined none].freeze
      SOURCE_REFERENCE_PATTERN =
        /[ \t]*(?:\[\[source_\d+\]\]|\[source_\d+\](?:\([^)]+\))?|\(source_\d+\))(?:[ \t]*,[ \t]*(?:\[\[source_\d+\]\]|\[source_\d+\](?:\([^)]+\))?|\(source_\d+\)))*/i
      SOURCES_SECTION_PATTERN =
        /\n{2,}(?:\#{1,6}\s*)?(?:\*\*|__)?(?:sources|references)\s*:?(?:\*\*|__)?\s*\n.*\z/im

      class << self
        def meaningful_answer?(answer)
          normalized = answer.to_s.squish.downcase
          normalized.present? &&
            PLACEHOLDER_ANSWERS.none? { |placeholder| placeholder.start_with?(normalized) } &&
            normalized.match?(/[[:alnum:]]/)
        end
      end
      def initialize(user:, ai_agent:, llm_model:, cancel_manager: nil)
        @user = user
        @ai_agent = ai_agent
        @llm_model = llm_model
        @cancel_manager = cancel_manager
      end

      def call(
        query:,
        candidates:,
        keyword_query: query,
        original_query_locale: nil,
        summary_detail: :balanced,
        related_count: DiscourseAi::Discoveries::MIN_RELATED_DISCUSSIONS
      )
        if candidates.empty?
          return(
            Result.new(answerable: false, source_refs: [], title: "", answer: "", follow_up: "")
          )
        end
        related_count = normalized_related_count(related_count)
        original_query_locale = normalized_original_query_locale(original_query_locale)

        context =
          DiscourseAi::Agents::BotContext.new(
            user: @user,
            messages: [
              {
                type: :user,
                content:
                  input(
                    query,
                    candidates,
                    keyword_query:,
                    original_query_locale:,
                    summary_detail:,
                    related_count:,
                  ),
              },
            ],
            skip_show_thinking: true,
            feature_name: "ask_ai",
            cancel_manager: @cancel_manager,
          )
        bot =
          DiscourseAi::Agents::Bot.as(
            Discourse.system_user,
            agent: @ai_agent.class_instance.new,
            model: @llm_model,
          )
        values = { answerable: nil, source_refs: nil, title: +"", answer: +"", follow_up: +"" }

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

          follow_up = partial.read_buffered_property(:follow_up)
          values[:follow_up] << follow_up if follow_up.present?

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
            follow_up: values[:follow_up].to_s.strip,
          )
        return empty_result if !result.answerable

        valid_result?(result, candidates:, related_count:) ? result : empty_result
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
        Result.new(answerable: false, source_refs: [], title: "", answer: "", follow_up: "")
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
        keyword_query:,
        original_query_locale:,
        summary_detail: :balanced,
        related_count: DiscourseAi::Discoveries::MIN_RELATED_DISCUSSIONS
      )
        JSON.generate(
          original_query: query,
          original_query_locale:,
          retrieval: {
            keyword_query:,
          },
          settings: {
            summary_detail:,
            related_count:,
          },
          candidates: candidates.map { |candidate| candidate_input(candidate) },
        )
      end

      def candidate_input(candidate)
        input =
          candidate.slice(
            "source_ref",
            "title",
            "url",
            "username",
            "created",
            "category",
            "likes",
            "topic_views",
            "topic_likes",
            "topic_replies",
            "tags",
            "author_is_staff",
            "is_topic_op",
          ).compact
        if candidate["passages"].present?
          input["passages"] = candidate["passages"].map do |passage|
            passage.slice("post_number", "excerpt").compact
          end
        else
          input["excerpt"] = candidate["excerpt"] if candidate["excerpt"]
        end
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

      def normalized_original_query_locale(locale)
        locale = LocaleNormalizer.normalize_to_i18n(locale)&.to_s
        return locale if LocaleSiteSetting.supported_locales.include?(locale)

        @user.effective_locale
      end
    end
  end
end
