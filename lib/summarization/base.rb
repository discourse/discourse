# frozen_string_literal: true

# Base class that defines the interface that every summarization
# strategy must implement.
# Above each method, you'll find an explanation of what
# it does and what it should return.

module Summarization
  class Base
    class << self
      def available_strategies
        DiscoursePluginRegistry.summarization_strategies
      end

      def find_strategy(strategy_model)
        available_strategies.detect { |s| s.model == strategy_model }
      end

      def selected_strategy
        return if SiteSetting.summarization_strategy.blank?

        find_strategy(SiteSetting.summarization_strategy)
      end

      def can_see_summary?(target, user)
        return false if SiteSetting.summarization_strategy.blank?

        has_cached_summary = SummarySection.exists?(target: target, meta_section_id: nil)
        return has_cached_summary if user.nil?

        has_cached_summary || can_request_summary_for?(user)
      end

      def can_request_summary_for?(user)
        return false unless user

        user_group_ids = user.group_ids

        SiteSetting.custom_summarization_allowed_groups_map.any? do |group_id|
          user_group_ids.include?(group_id)
        end
      end
    end

    # Some strategies could require other conditions to work correctly,
    # like site settings.
    # This method gets called when admins attempt to select it,
    # checking if we met those conditions.
    def correctly_configured?
      raise NotImplemented
    end

    # Strategy name to display to admins in the available strategies dropdown.
    def display_name
      raise NotImplemented
    end

    # If we don't meet the conditions to enable this strategy,
    # we'll display this hint as an error to admins.
    def configuration_hint
      raise NotImplemented
    end

    # The idea behind this method is "give me a collection of texts,
    # and I'll handle the summarization to the best of my capabilities.".
    # It's important to emphasize the "collection of texts" part, which implies
    # it's not tied to any model and expects the "content" to be a hash instead.
    #
    # @param content { Hash } - Includes the content to summarize, plus additional
    # context to help the strategy produce a better result. Keys present in the content hash:
    #  - resource_path (optional): Helps the strategy build links to the content in the summary (e.g. "/t/-/:topic_id/POST_NUMBER")
    #  - content_title (optional): Provides guidance about what the content is about.
    #  - contents (required): Array of hashes with content to summarize (e.g. [{ poster: "asd", id: 1, text: "This is a text" }])
    #    All keys are required.
    # @param &on_partial_blk { Block - Optional } - If the strategy supports it, the passed block
    # will get called with partial summarized text as its generated.
    #
    # @returns { Hash } - The summarized content, plus chunks if the content couldn't be summarized in one pass. Example:
    #   {
    #     summary: "This is the final summary",
    #     chunks: [
    #       { ids: [topic.first_post.post_number], summary: "this is the first chunk" },
    #       { ids: [post_1.post_number, post_2.post_number], summary: "this is the second chunk" },
    #     ],
    #   }
    def summarize(content)
      raise NotImplemented
    end

    # Returns the string we'll store in the selected strategy site setting.
    def model
      raise NotImplemented
    end
  end
end
