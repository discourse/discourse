# frozen_string_literal: true

module DiscourseAi
  module Summarization
    # This class offers a generic way of summarizing content from multiple sources using different prompts.
    class FoldContent
      class MissingToolOutput < StandardError
      end

      def initialize(bot, strategy, persist_summaries: true)
        @bot = bot
        @strategy = strategy
        @persist_summaries = persist_summaries
      end

      attr_reader :bot, :strategy

      # @param user { User } - User object used for auditing usage.
      # @param &on_partial_blk { Block - Optional } - The passed block will get called with the LLM partial response.
      #
      # This method doesn't care if we already have an up to date summary. It always regenerate.
      #
      # @returns { AiSummary } - Resulting summary.
      def summarize(user, &on_partial_blk)
        truncated_content = content_to_summarize.map { |cts| truncate(cts) }

        summary = fold(truncated_content, user, &on_partial_blk)

        if persist_summaries
          AiSummary.store!(strategy, llm_model, summary, truncated_content, human: user&.human?)
        else
          AiSummary.new(summarized_text: summary)
        end
      end

      # @returns { AiSummary } - Resulting summary.
      #
      # Finds a summary matching the target and strategy. Marks it as outdated if the strategy found newer content
      def existing_summary
        if !defined?(@existing_summary)
          summaries = AiSummary.where(target: strategy.target, summary_type: strategy.type)
          summary = summaries.find_by(locale: strategy.locale)

          if summary.blank? && strategy.locale.present?
            summary =
              summaries
                .where.not(locale: nil)
                .find { |candidate| LocaleNormalizer.is_same?(candidate.locale, strategy.locale) }
          end

          if summary
            @existing_summary = summary

            summary.mark_as_outdated if outdated_summary?(summary)
          end
        end
        @existing_summary
      end

      def truncate(item)
        item_content = item[:text].to_s
        truncation_length = 500
        tokenizer = llm_model.tokenizer_class
        strict = SiteSetting.ai_strict_token_counting
        return item if tokenizer.below_limit?(item_content, truncation_length * 2, strict:)

        # From https://www.unicode.org/reports/tr29/#Grapheme_Cluster_Boundaries:
        #
        # A single Unicode code point is often, but not always, the same as a basic unit of a
        # writing system, or what a typical user might think of as a "character." There are cases
        # where such a basic unit is made up of multiple code points. To avoid ambiguity with
        # encoding terminology, TR29 recommends reasoning in terms of a user-perceived character
        # (a grapheme cluster). For example, "G" + grave-accent is perceived as a single character
        # even though it is represented by two code points.
        #
        # Split using grapheme clusters so multi-codepoint emoji remain intact.
        graphemes = item_content.grapheme_clusters
        midpoint = graphemes.size / 2

        first_half = graphemes[...midpoint].join
        second_half = graphemes[midpoint..].join

        head = tokenizer.truncate(first_half, truncation_length, strict:)
        tail_length = tokenizer.decode(tokenizer.encode(second_half).last(truncation_length)).length
        tail = second_half[(second_half.length - tail_length)..]
        item[:text] = "#{head} #{tail}"

        item
      end

      private

      attr_reader :persist_summaries

      def llm_model
        bot.llm.llm_model
      end

      def content_to_summarize
        @targets_data ||= strategy.targets_data
      end

      def latest_sha
        @latest_sha ||= AiSummary.build_sha(content_to_summarize.map { |c| c[:id] }.join)
      end

      def outdated_summary?(summary)
        if (fingerprint = strategy.summary_fingerprint)
          return true if summary.original_content_sha != fingerprint[:original_content_sha]
          return true if fingerprint[:latest_version_at]&.> summary.updated_at

          return false
        end

        summary.original_content_sha != latest_sha ||
          content_to_summarize.any? { |cts| cts[:last_version_at] > summary.updated_at }
      end

      # @param items { Array<Hash> } - Content to summarize. Structure will be: { poster: who wrote the content, id: a way to order content, text: content }
      # @param user { User } - User object used for auditing usage.
      # @param &on_partial_blk { Block - Optional } - The passed block will get called with the LLM partial response.
      #
      # @returns { String } - Resulting summary.
      def fold(items, user, &on_partial_blk)
        tokenizer = llm_model.tokenizer_class
        tokens_left = available_tokens
        content_in_window = []

        items.each do |item|
          as_text = "(#{item[:id]} #{item[:poster]} said: #{item[:text]} "

          if tokenizer.below_limit?(
               as_text,
               tokens_left,
               strict: SiteSetting.ai_strict_token_counting,
             )
            content_in_window << item
            tokens_left -= tokenizer.size(as_text)
          else
            break
          end
        end

        context =
          DiscourseAi::Agents::BotContext.new(
            user: user,
            skip_show_thinking: true,
            feature_name: strategy.feature,
            resource_url: "#{Discourse.base_path}/t/-/#{strategy.target.id}",
            messages: strategy.as_llm_messages(content_in_window),
            bypass_response_format: strategy.output_tool.present?,
          )

        summary = +""
        tool_output = strategy.output_tool.present?

        buffer_blk =
          Proc.new do |partial, _, type|
            if tool_output
              if type == :custom_raw
                summary.replace(partial.to_s)
                on_partial_blk.call(summary) if on_partial_blk
              end
            elsif type == :structured_output
              json_summary_schema_key = bot.agent.response_format&.first.to_h
              partial.read_buffered_property_chunk(
                json_summary_schema_key["key"]&.to_sym,
              ) do |partial_summary|
                summary << partial_summary
                on_partial_blk.call(partial_summary) if on_partial_blk
              end
            elsif type.blank?
              # Assume response is a regular completion.
              summary << partial
              on_partial_blk.call(partial) if on_partial_blk
            end
          end

        bot.reply(context, &buffer_blk)

        if tool_output && summary.blank?
          raise MissingToolOutput, "The model did not set a topic summary"
        end

        summary
      end

      def available_tokens
        # Reserve tokens for the response and the base prompt
        # ~500 words
        reserved_tokens = 700

        llm_model.max_prompt_tokens - reserved_tokens
      end
    end
  end
end
