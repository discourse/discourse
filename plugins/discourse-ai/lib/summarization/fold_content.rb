# frozen_string_literal: true

module DiscourseAi
  module Summarization
    # This class offers a generic way of summarizing content from multiple sources using different prompts.
    #
    # It summarizes large amounts of content by recursively summarizing it in smaller chunks that
    # fit the given model context window, finally concatenating the disjoint summaries
    # into a final version.
    #
    class FoldContent
      def initialize(bot, strategy, persist_summaries: true)
        @bot = bot
        @strategy = strategy
        @persist_summaries = persist_summaries
      end

      attr_reader :bot, :strategy

      # @param user { User } - User object used for auditing usage.
      # @param &on_partial_blk { Block - Optional } - The passed block will get called with the LLM partial response.
      # Note: The block is only called with results of the final summary, not intermediate summaries.
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
          summary = AiSummary.find_by(target: strategy.target, summary_type: strategy.type)

          if summary
            @existing_summary = summary

            if summary.original_content_sha != latest_sha ||
                 content_to_summarize.any? { |cts| cts[:last_version_at] > summary.updated_at }
              summary.mark_as_outdated
            end
          end
        end
        @existing_summary
      end

      def delete_cached_summaries!
        AiSummary.where(target: strategy.target, summary_type: strategy.type).destroy_all
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

      # @param items { Array<Hash> } - Content to summarize. Structure will be: { poster: who wrote the content, id: a way to order content, text: content }
      # @param user { User } - User object used for auditing usage.
      # @param &on_partial_blk { Block - Optional } - The passed block will get called with the LLM partial response.
      # Note: The block is only called with results of the final summary, not intermediate summaries.
      #
      # The summarization algorithm.
      # It will summarize as much content summarize given the model's context window. If will prioriotize newer content in case it doesn't fit.
      #
      # @returns { String } - Resulting summary.
      def fold(items, user, &on_partial_blk)
        tokenizer = llm_model.tokenizer_class
        tokens_left = available_tokens
        content_in_window = []

        items.each_with_index do |item, idx|
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
          DiscourseAi::Personas::BotContext.new(
            user: user,
            skip_tool_details: true,
            feature_name: strategy.feature,
            resource_url: "#{Discourse.base_path}/t/-/#{strategy.target.id}",
            messages: strategy.as_llm_messages(content_in_window),
          )

        summary = +""

        buffer_blk =
          Proc.new do |partial, _, type|
            if type == :structured_output
              json_summary_schema_key = bot.persona.response_format&.first.to_h
              partial_summary =
                partial.read_buffered_property(json_summary_schema_key["key"]&.to_sym)

              if partial_summary.present?
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

        summary
      end

      def available_tokens
        # Reserve tokens for the response and the base prompt
        # ~500 words
        reserved_tokens = 700

        llm_model.max_prompt_tokens - reserved_tokens
      end

      def truncate(item)
        item_content = item[:text].to_s
        split_1, split_2 =
          [item_content[0, item_content.size / 2], item_content[(item_content.size / 2)..-1]]

        truncation_length = 500
        tokenizer = llm_model.tokenizer_class

        item[:text] = [
          tokenizer.truncate(
            split_1,
            truncation_length,
            strict: SiteSetting.ai_strict_token_counting,
          ),
          tokenizer.truncate(
            split_2.reverse,
            truncation_length,
            strict: SiteSetting.ai_strict_token_counting,
          ).reverse,
        ].join(" ")

        item
      end
    end
  end
end
