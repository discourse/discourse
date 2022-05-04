# frozen_string_literal: true

class UserTestBookmarkSerializer < UserBookmarkBaseSerializer; end
class UserTestBookmarkable < BaseBookmarkable
  MODEL = User
  SERIALIZER = UserTestBookmarkSerializer

  def initialize
    super(MODEL, SERIALIZER)
    @preload_associations = [:topic_users, :tags, { posts: :user }]
  end

  def list_query(user, guardian)
    user.bookmarks.joins(
      "INNER JOIN users ON users.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'User'"
    ).where(bookmarkable_type: "User")
  end

  def search_query(bookmarks, query, ts_query, &bookmarkable_search)
    bookmarks.where("users.username ILIKE ?", query)
  end

  def reminder_handler(bookmark)
    # noop
  end

  def reminder_conditions(bookmark)
    bookmark.bookmarkable.present?
  end

  def can_see?(guardian, bookmark)
    true
  end
end

def register_test_bookmarkable
  Bookmark.register_bookmarkable(UserTestBookmarkable)
end
