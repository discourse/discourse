# frozen_string_literal: true

module DiscourseAi
  module Discoveries
    # The topics a conversation continued from a combined search has cited:
    # the answer's sources, then the topics each reply links to, with what a
    # topic list row shows of them. Each is numbered by the reply that cited
    # it, so later citations can rank higher.
    class CitedTopics
      TOPIC_PATH = %r{/t/(?:[^/\s?#]+/)?(\d+)}

      def initialize(topic:, guardian:)
        @topic = topic
        @guardian = guardian
      end

      # @return [Hash] how many replies there are, and each cited topic with the
      #   reply it was cited in, counting the answer as the first
      def as_json(*)
        citations =
          sources +
            replies.flat_map.with_index do |topic_ids, turn|
              topic_ids.map { |topic_id| { topic_id:, turn: } }
            end
        topics =
          Topic
            .where(id: citations.map { |citation| citation[:topic_id] }.uniq)
            .select { |topic| @guardian.can_see?(topic) }
            .index_by(&:id)

        cited =
          citations.filter_map do |citation|
            topic = topics[citation[:topic_id]]
            next if topic.nil?

            {
              topic_id: topic.id,
              turn: citation[:turn],
              title: topic.title,
              url: topic.relative_url,
              category_id: topic.category_id,
              bumped_at: topic.bumped_at,
              reply_count: topic.posts_count - 1,
            }
          end

        { replies: replies.size, topics: cited }
      end

      private

      def sources
        Array(@topic.custom_fields[ContinueConversation::TOPIC_SOURCES_FIELD]).map do |source|
          { topic_id: source["topic_id"].to_i, turn: 0 }
        end
      end

      # The topics each reply links to, in order. Every post after the search
      # that its asker did not write is a reply.
      def replies
        @replies ||=
          @topic
            .posts
            .where.not(user_id: @topic.user_id)
            .where("post_number > 1")
            .order(:post_number)
            .pluck(:cooked)
            .map { |cooked| linked_topic_ids(cooked) }
      end

      def linked_topic_ids(cooked)
        Nokogiri::HTML5
          .fragment(cooked)
          .css("a[href]")
          .filter_map do |link|
            href = link["href"]
            next if !href.start_with?("/", Discourse.base_url)

            href[TOPIC_PATH, 1]&.to_i
          end
          .uniq
          .excluding(@topic.id)
      end
    end
  end
end
