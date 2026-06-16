# frozen_string_literal: true

module DiscoursePostEvent
  # Builds, per post, the data needed to render an interactive event card for the
  # internal topic oneboxes that point at an event topic. Mirrors
  # ContentLocalization::OneboxLocalizer: batched via TopicLink and surfaced on
  # the post serializer (see TopicView.on_preload + PostSerializer#event_oneboxes)
  # so the client renders the card from inline data instead of fetching each
  # event individually.
  #
  # Returns { source_post_id => { linked_topic_id => serialized_event } }. It's
  # keyed by topic id so the client can match each `aside.quote[data-topic]`
  # onebox to its event (mirrors how core's localized_oneboxes are matched).
  class EventOneboxData
    def self.build(posts:, guardian:)
      new(posts:, guardian:).build
    end

    def initialize(posts:, guardian:)
      @posts = posts
      @guardian = guardian
    end

    def build
      return {} if @posts.blank?

      # internal links the page's posts point at (indexed lookup, no cooked scan)
      links =
        TopicLink
          .where(post_id: @posts.map(&:id), internal: true, reflection: false)
          .where.not(link_topic_id: nil)
          .pluck(:post_id, :link_topic_id)
          .uniq
      return {} if links.empty?

      topic_ids = links.map(&:last).uniq

      first_post_ids = Post.where(topic_id: topic_ids, post_number: 1, deleted_at: nil).pluck(:id)
      return {} if first_post_ids.empty?

      events_by_topic =
        DiscoursePostEvent::Event
          .where(id: first_post_ids)
          .includes(:image_upload, post: [:user, { topic: :category }])
          .index_by { |event| event.post.topic_id }
      return {} if events_by_topic.empty?

      serialized = {}
      result = {}

      links.each do |source_post_id, link_topic_id|
        event = events_by_topic[link_topic_id]
        next if event.nil?
        next unless @guardian.can_see?(event.post)

        serialized[event.id] ||= DiscoursePostEvent::EventSerializer.new(
          event,
          scope: @guardian,
          root: false,
        ).as_json

        (result[source_post_id] ||= {})[link_topic_id] = serialized[event.id]
      end

      result
    end
  end
end
