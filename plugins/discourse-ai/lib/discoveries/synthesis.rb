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
            agent: agent_for(related_count),
            model: @llm_model,
          )
        values = { answerable: nil, source_refs: nil, title: +"", answer: +"", follow_up: +"" }

        bot.reply(context) do |partial, _, type|
          next if type != :structured_output

          answerable = partial.read_buffered_property(:answerable)
          values[:answerable] = answerable if !answerable.nil?

          # Locking in a partial array would make later updates look like a changed selection.
          source_refs = partial.read_buffered_property(:source_refs)
          if !source_refs.nil? && partial.property_complete?(:source_refs)
            values[:source_refs] = source_refs
          end

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
            source_refs: known_source_refs(values[:source_refs], candidates:, related_count:),
            title: values[:title].to_s.strip,
            answer: answer_without_source_references(values[:answer]),
            follow_up: values[:follow_up].to_s.strip,
          )
        if !result.answerable || result.source_refs.empty? ||
             !self.class.meaningful_answer?(result.answer)
          return empty_result
        end

        result
      end

      def self.meaningful_answer?(answer)
        normalized = answer.to_s.squish.downcase
        normalized.present? &&
          PLACEHOLDER_ANSWERS.none? { |placeholder| placeholder.start_with?(normalized) } &&
          normalized.match?(/[[:alnum:]]/)
      end

      private

      # The agent's stored format caps the sources at the shared setting, which
      # would cut short a request that asks for more, so it follows the request.
      def agent_for(related_count)
        agent = @ai_agent.class_instance.new
        format =
          agent.response_format&.map do |field|
            field["key"] == "source_refs" ? field.merge("max_items" => related_count) : field
          end
        agent.define_singleton_method(:response_format) { format } if format
        agent
      end

      def known_source_refs(source_refs, candidates:, related_count:)
        candidate_refs = candidates.pluck("source_ref")
        Array(source_refs)
          .uniq
          .select { |source_ref| candidate_refs.include?(source_ref) }
          .first(related_count)
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

      # Most of each candidate is metadata rather than content, so it is kept
      # to what the model can use: days rather than timestamps, links without
      # the slug that repeats the title, and flags only when they are set.
      # Whether a passage is the topic's first post shows in its post_number.
      def candidate_input(candidate)
        input =
          candidate.slice(
            "source_ref",
            "title",
            "username",
            "category",
            "likes",
            "topic_views",
            "topic_likes",
            "topic_replies",
            "tags",
            "source_name",
          ).compact
        input["url"] = slugless_url(candidate["url"]) if candidate["url"]
        input["created"] = day(candidate["created"]) if candidate["created"]
        input["author_is_staff"] = true if candidate["author_is_staff"]
        input["solved"] = true if candidate["solved"]
        if candidate["passages"].present?
          input["passages"] = candidate["passages"].map do |passage|
            passage.slice("post_number", "excerpt", "answer").compact
          end
        else
          input["excerpt"] = candidate["excerpt"] if candidate["excerpt"]
        end
        last_updated_at = day(candidate["post_updated_at"] || candidate["published_at"])
        input["last_updated_at"] = last_updated_at if last_updated_at != input["created"]
        input.compact
      end

      def slugless_url(url)
        url.sub(%r{\A(#{Regexp.escape(Discourse.base_path)}/t/)(?!\d+(?:/|\z))[^/]+/(?=\d)}, '\\1')
      end

      def day(value)
        value = Time.iso8601(value) if value.is_a?(String)
        value&.utc&.to_date&.iso8601
      rescue ArgumentError
        nil
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
