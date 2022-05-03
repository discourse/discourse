# frozen_string_literal: true

##
# Anything that we want to be able to bookmark must be registered as a
# bookmarkable type using Bookmark.register_bookmarkable(bookmarkable_klass),
# where the bookmarkable_klass is a class that implements this BaseBookmarkable
# interface. Some examples are TopicBookmarkable and PostBookmarkable.
#
# These methods are then called by the Bookmarkable class through a public
# interface, used in places where we need to list, send reminders for,
# or otherwise interact with bookmarks in a way that is unique to the
# bookmarkable type.
class BaseBookmarkable
  attr_reader :model, :serializer, :preload_associations

  def initialize(model, serializer)
    @model = model
    @serializer = serializer
  end

  def list_query(user, guardian)
    throw NotImplementedError
  end

  def search_query(bookmarks, query, ts_query, &bookmarkable_search)
    throw NotImplementedError
  end

  def reminder_handler(bookmark)
    throw NotImplementedError
  end

  def reminder_conditions(bookmark)
    throw NotImplementedError
  end
end
