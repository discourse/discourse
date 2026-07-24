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

      # cross-topic internal links (indexed lookup, no cooked scan). TopicLink
      # does not record a topic that links itself, so same-topic oneboxes are
      # detected from cooked further down.
      links =
        TopicLink
          .where(post_id: @posts.map(&:id), internal: true, reflection: false)
          .where.not(link_topic_id: nil)
          .pluck(:post_id, :link_topic_id)
          .uniq

      # the topic being viewed, only when it's itself an event (cheap custom-field
      # check, so non-event topic views do no extra work)
      topic = @posts.first.topic
      own_topic_id = topic&.event_starts_at ? topic.id : nil

      topic_ids = links.map(&:last)
      topic_ids << own_topic_id if own_topic_id
      topic_ids.uniq!
      return {} if topic_ids.empty?

      first_post_ids = Post.where(topic_id: topic_ids, post_number: 1, deleted_at: nil).pluck(:id)
      return {} if first_post_ids.empty?

      events_by_topic =
        DiscoursePostEvent::Event
          .where(id: first_post_ids)
          .includes(:image_upload, post: [:user, { topic: :category }])
          .index_by { |event| event.post.topic_id }
      return {} if events_by_topic.empty?

      @serialized = {}
      result = {}

      links.each do |source_post_id, link_topic_id|
        event = events_by_topic[link_topic_id]
        next if event.nil? || !@guardian.can_see?(event.post)
        (result[source_post_id] ||= {})[link_topic_id] = serialize(event)
      end

      own_event = own_topic_id && events_by_topic[own_topic_id]
      if own_event && @guardian.can_see?(own_event.post)
        each_self_onebox_post(own_topic_id) do |post_id|
          (result[post_id] ||= {})[own_topic_id] = serialize(own_event)
        end
      end

      result
    end

    private

    def serialize(event)
      @serialized[event.id] ||= DiscoursePostEvent::EventSerializer.new(
        event,
        scope: @guardian,
        root: false,
      ).as_json
    end

    # yields the id of each post whose cooked oneboxes its own (event) topic. A
    # same-topic onebox is `aside.quote[data-post="1"]` without a data-username
    # (which would mark a manual quote); the cheap include? skips parsing posts
    # that don't reference the topic at all.
    def each_self_onebox_post(topic_id)
      marker = %{data-topic="#{topic_id}"}
      @posts.each do |post|
        next if post.cooked.blank? || !post.cooked.include?(marker)

        onebox =
          Nokogiri::HTML5
            .fragment(post.cooked)
            .css(%{aside.quote[data-topic="#{topic_id}"][data-post="1"]})
            .any? { |aside| aside["data-username"].blank? }

        yield(post.id) if onebox
      end
    end
  end
end
