# frozen_string_literal: true

class PostBookmarkable < BaseBookmarkable
  MODEL = Post
  SERIALIZER = UserPostBookmarkSerializer

  def initialize
    super(MODEL, SERIALIZER)
    @preload_associations = [{ topic: [:topic_users, :tags] }, :user]
  end

  def list_query(user, guardian)
    topics = Topic.listable_topics.secured(guardian)
    pms = Topic.private_messages_for_user(user)
    post_bookmarks = user
      .bookmarks_of_type("Post")
      .joins("INNER JOIN posts ON posts.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Post'")
      .joins("LEFT JOIN topics ON topics.id = posts.topic_id")
      .joins("LEFT JOIN topic_users ON topic_users.topic_id = topics.id")
      .where("topic_users.user_id = ?", user.id)
    guardian.filter_allowed_categories(
      post_bookmarks.merge(topics.or(pms)).merge(Post.secured(guardian))
    )
  end

  def search_query(bookmarks, query, ts_query, &bookmarkable_search)
    bookmarkable_search.call(
      bookmarks.joins(
        "LEFT JOIN post_search_data ON post_search_data.post_id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Post'"
      ),
      "#{ts_query} @@ post_search_data.search_data"
    )
  end

  def reminder_handler(bookmark)
    bookmark.user.notifications.create!(
      notification_type: Notification.types[:bookmark_reminder],
      topic_id: bookmark.bookmarkable.topic_id,
      post_number: bookmark.bookmarkable.post_number,
      data: {
        topic_title: bookmark.bookmarkable.topic.title,
        display_username: bookmark.user.username,
        bookmark_name: bookmark.name
      }.to_json
    )
  end

  def reminder_conditions(bookmark)
    bookmark.bookmarkable.present?
  end
end
