# frozen_string_literal: true

class TopicBookmarkable < BaseBookmarkable
  include TopicPostBookmarkableHelper

  class << self
    def model
      Topic
    end

    def serializer
      UserTopicBookmarkSerializer
    end

    def preload_associations
      [{ category: :parent_category }, :tags, { first_post: :user }]
    end

    def perform_custom_preload!(topic_bookmarks, guardian)
      topics = topic_bookmarks.map(&:bookmarkable)
      topic_user_lookup = TopicUser.lookup_for(guardian.user, topics)

      topics.each { |topic| topic.user_data = topic_user_lookup[topic.id] }
    end

    def list_query(user, guardian)
      topics = Topic.listable_topics.secured(guardian)
      pms = Topic.private_messages_for_user(user)
      first_posts = guardian.filter_hidden_posts(Post.secured(guardian).where(deleted_at: nil))
      topic_bookmarks =
        user
          .bookmarks_of_type("Topic")
          .joins(
            "INNER JOIN topics ON topics.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Topic'",
          )
          .joins("INNER JOIN posts ON posts.topic_id = topics.id AND posts.post_number = 1")
          .joins("LEFT JOIN topic_users ON topic_users.topic_id = topics.id")
          .where("topic_users.user_id = ?", user.id)
      guardian.filter_allowed_categories(topic_bookmarks.merge(topics.or(pms)).merge(first_posts))
    end

    def search_query(bookmarks, query, ts_query, &bookmarkable_search)
      bookmarkable_search.call(
        bookmarks.joins("LEFT JOIN post_search_data ON post_search_data.post_id = posts.id"),
        "#{ts_query} @@ post_search_data.search_data",
      )
    end

    def reminder_handler(bookmark)
      send_reminder_notification(
        bookmark,
        topic_id: bookmark.bookmarkable_id,
        post_number: 1,
        data: {
          title: bookmark.bookmarkable.title,
          bookmarkable_url: bookmark.bookmarkable.first_post.url,
        },
      )
    end

    def reminder_conditions(bookmark)
      bookmark.bookmarkable.present? && can_see?(bookmark.user.guardian, bookmark)
    end

    def can_see?(guardian, bookmark)
      can_see_bookmarkable?(guardian, bookmark.bookmarkable)
    end

    def can_see_bookmarkable?(guardian, bookmarkable)
      guardian.can_see_post?(bookmarkable&.first_post)
    end

    def bookmark_metadata(bookmark, user)
      { topic_bookmarked: Bookmark.for_user_in_topic(user.id, bookmark.bookmarkable.id).exists? }
    end

    def validate_before_create(guardian, bookmarkable)
      raise Discourse::InvalidAccess if !can_see_bookmarkable?(guardian, bookmarkable)
    end

    def after_create(guardian, bookmark, opts)
      sync_topic_user_bookmarked(guardian.user, bookmark.bookmarkable, opts)
    end

    def after_destroy(guardian, bookmark, opts)
      sync_topic_user_bookmarked(guardian.user, bookmark.bookmarkable, opts)
    end

    def cleanup_deleted
      related_topics = DB.query(<<~SQL, grace_time: 3.days.ago)
      DELETE FROM bookmarks b
      USING topics t
      WHERE b.bookmarkable_id = t.id AND b.bookmarkable_type = 'Topic'
      AND (t.deleted_at < :grace_time)
      RETURNING t.id AS topic_id
    SQL

      related_topics_ids = related_topics.map(&:topic_id).uniq
      related_topics_ids.each do |topic_id|
        Jobs.enqueue(:sync_topic_user_bookmarked, topic_id: topic_id)
      end
    end
  end
end
