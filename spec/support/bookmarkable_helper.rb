# frozen_string_literal: true

class UserTestBookmarkSerializer < UserBookmarkBaseSerializer
  def title
    fancy_title
  end

  def fancy_title
    @fancy_title ||= user.username
  end

  def cooked
    user.user_profile&.bio_cooked
  end

  def bookmarkable_user
    @bookmarkable_user ||= user
  end

  def bookmarkable_url
    "#{Discourse.base_url}/u/#{user.username}"
  end

  def excerpt
    return nil unless cooked
    @excerpt ||= PrettyText.excerpt(cooked, 300, keep_emoji_images: true)
  end

  private

  def user
    object.bookmarkable
  end
end

class UserTestBookmarkable < BaseBookmarkable
  def self.model
    User
  end

  def self.serializer
    UserTestBookmarkSerializer
  end

  def self.preload_associations
    [:topic_users, :tags, { posts: :user }]
  end

  def self.list_query(user, guardian)
    user
      .bookmarks
      .joins(
        "INNER JOIN users ON users.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'User'",
      )
      .where(bookmarkable_type: "User")
  end

  def self.search_query(bookmarks, query, ts_query, &bookmarkable_search)
    bookmarks.where("users.username ILIKE ?", query)
  end

  def self.reminder_handler(bookmark)
    # noop
  end

  def self.reminder_conditions(bookmark)
    bookmark.bookmarkable.present?
  end

  def self.can_see?(guardian, bookmark)
    true
  end
end

def register_test_bookmarkable
  Bookmark.register_bookmarkable(UserTestBookmarkable)
end
