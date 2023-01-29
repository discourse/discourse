# frozen_string_literal: true

class PostBookmarkable < BaseBookmarkable
  include TopicPostBookmarkableHelper

  def self.model
    Post
  end

  def self.serializer
    UserPostBookmarkSerializer
  end

  def self.preload_associations
    [{ topic: [:tags] }, :user]
  end

  def self.list_query(user, guardian)
    topics = Topic.listable_topics.secured(guardian)
    pms = Topic.private_messages_for_user(user)
    post_bookmarks =
      user
        .bookmarks_of_type("Post")
        .joins(
          "INNER JOIN posts ON posts.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Post'",
        )
        .joins("LEFT JOIN topics ON topics.id = posts.topic_id")
        .joins("LEFT JOIN topic_users ON topic_users.topic_id = topics.id")
        .where("topic_users.user_id = ?", user.id)
    guardian.filter_allowed_categories(
      post_bookmarks.merge(topics.or(pms)).merge(Post.secured(guardian)),
    )
  end

  def self.search_query(bookmarks, query, ts_query, &bookmarkable_search)
    bookmarkable_search.call(
      bookmarks.joins(
        "LEFT JOIN post_search_data ON post_search_data.post_id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Post'",
      ),
      "#{ts_query} @@ post_search_data.search_data",
    )
  end

  def self.reminder_handler(bookmark)
    send_reminder_notification(
      bookmark,
      topic_id: bookmark.bookmarkable.topic_id,
      post_number: bookmark.bookmarkable.post_number,
      data: {
        title: bookmark.bookmarkable.topic.title,
        bookmarkable_url: bookmark.bookmarkable.url,
      },
    )
  end

  def self.reminder_conditions(bookmark)
    bookmark.bookmarkable.present? && bookmark.bookmarkable.topic.present?
  end

  def self.can_see?(guardian, bookmark)
    guardian.can_see_post?(bookmark.bookmarkable)
  end

  def self.bookmark_metadata(bookmark, user)
    {
      topic_bookmarked: Bookmark.for_user_in_topic(user.id, bookmark.bookmarkable.topic_id).exists?,
    }
  end

  def self.validate_before_create(guardian, bookmarkable)
    if bookmarkable.blank? || bookmarkable.topic.blank? ||
         !guardian.can_see_topic?(bookmarkable.topic) || !guardian.can_see_post?(bookmarkable)
      raise Discourse::InvalidAccess
    end
  end

  def self.after_create(guardian, bookmark, opts)
    sync_topic_user_bookmarked(guardian.user, bookmark.bookmarkable.topic, opts)
  end

  def self.after_destroy(guardian, bookmark, opts)
    sync_topic_user_bookmarked(guardian.user, bookmark.bookmarkable.topic, opts)
  end

  def self.cleanup_deleted
    related_topics = DB.query(<<~SQL, grace_time: 3.days.ago)
      DELETE FROM bookmarks b
      USING topics t, posts p
      WHERE t.id = p.topic_id AND b.bookmarkable_id = p.id AND b.bookmarkable_type = 'Post'
      AND (t.deleted_at < :grace_time OR p.deleted_at < :grace_time)
      RETURNING t.id AS topic_id
    SQL

    related_topics_ids = related_topics.map(&:topic_id).uniq
    related_topics_ids.each do |topic_id|
      Jobs.enqueue(:sync_topic_user_bookmarked, topic_id: topic_id)
    end
  end
end
