# frozen_string_literal: true

class TopicBookmarkable < BaseBookmarkable
  def self.model
    Topic
  end

  def self.serializer
    UserTopicBookmarkSerializer
  end

  def self.preload_associations
    [:topic_users, :tags, { posts: :user }]
  end

  def self.list_query(user, guardian)
    topics = Topic.listable_topics.secured(guardian)
    pms = Topic.private_messages_for_user(user)
    topic_bookmarks = user
      .bookmarks_of_type("Topic")
      .joins("INNER JOIN topics ON topics.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Topic'")
      .joins("LEFT JOIN topic_users ON topic_users.topic_id = topics.id")
      .where("topic_users.user_id = ?", user.id)
    guardian.filter_allowed_categories(topic_bookmarks.merge(topics.or(pms)))
  end

  def self.search_query(bookmarks, query, ts_query, &bookmarkable_search)
    bookmarkable_search.call(
      bookmarks
      .joins("LEFT JOIN posts ON posts.topic_id = topics.id AND posts.post_number = 1")
      .joins("LEFT JOIN post_search_data ON post_search_data.post_id = posts.id"),
    "#{ts_query} @@ post_search_data.search_data"
    )
  end

  def self.reminder_handler(bookmark)
    bookmark.user.notifications.create!(
      notification_type: Notification.types[:bookmark_reminder],
      topic_id: bookmark.bookmarkable_id,
      post_number: 1,
      data: {
        title: bookmark.bookmarkable.title,
        display_username: bookmark.user.username,
        bookmark_name: bookmark.name,
        bookmarkable_url: bookmark.bookmarkable.first_post.url
      }.to_json
    )
  end

  def self.reminder_conditions(bookmark)
    bookmark.bookmarkable.present?
  end

  def self.can_see?(guardian, bookmark)
    guardian.can_see_topic?(bookmark.bookmarkable)
  end
end
