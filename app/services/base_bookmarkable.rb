# frozen_string_literal: true

##
# Anything that we want to be able to bookmark must be registered as a
# bookmarkable type using Bookmark.register_bookmarkable(bookmarkable_klass),
# where the bookmarkable_klass is a class that implements this BaseBookmarkable
# interface. Some examples are TopicBookmarkable and PostBookmarkable.
#
# See BaseBookmarkable for documentation on what return types should be
# and what the arguments to the methods are.
#
# These methods are then called by the Bookmarkable class through a public
# interface, used in places where we need to list, send reminders for,
# or otherwise interact with bookmarks in a way that is unique to the
# bookmarkable type.
class BaseBookmarkable
  attr_reader :model, :serializer, :preload_associations

  ##
  # @param [ActiveRecord::Base] model The ActiveRecord model class which will be used to denote
  #                                   the type of the bookmarkable upon registration along with
  #                                   querying.
  # @param [ApplicationSerializer] serializer The serializer class inheriting from UserBookmarkBaseSerializer
  # @param [Array] preload_associations Used for preloading associations on the bookmarks for listing
  #                                     purposes. Should be in the same format used for .includes() e.g.
  #
  #                                     [{ topic: [:topic_users, :tags] }, :user]
  def initialize(model, serializer, preload_associations = nil)
    @model = model
    @serializer = serializer
    @preload_associations = preload_associations
  end

  def has_preloads?
    @preload_associations.present?
  end

  def list_query(user, guardian)
    raise NotImplementedError
  end

  def search_query(bookmarks, query, ts_query, &bookmarkable_search)
    raise NotImplementedError
  end

  def reminder_handler(bookmark)
    raise NotImplementedError
  end

  def reminder_conditions(bookmark)
    raise NotImplementedError
  end
end
