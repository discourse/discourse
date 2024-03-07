# frozen_string_literal: true
#
# Should only be created via the Plugin::Instance#register_bookmarkable
# method; this is used to let the BookmarkQuery class query and
# search additional bookmarks for the user bookmark list, and
# also to enumerate on the registered RegisteredBookmarkable types.
#
# Post and Topic bookmarkables are registered by default.
#
# Anything other than types registered in this way will throw an error
# when trying to save the Bookmark record. All things that are bookmarkable
# must be registered in this way.
#
# See Plugin::Instance#register_bookmarkable for some examples on how registering
# bookmarkables works.
#
# See BaseBookmarkable for documentation on what return types should be
# and what the arguments to the methods are.
class RegisteredBookmarkable
  attr_reader :bookmarkable_klass

  delegate :model, :serializer, to: :@bookmarkable_klass
  delegate :table_name, to: :model

  def initialize(bookmarkable_klass)
    @bookmarkable_klass = bookmarkable_klass
  end

  def perform_list_query(user, guardian)
    bookmarkable_klass.list_query(user, guardian)
  end

  ##
  # The block here warrants explanation -- when the search_query is called, we
  # call the provided block with the bookmark relation with additional joins
  # as well as the where_sql string, and then also add the additional OR bookmarks.name
  # filter. This is so every bookmarkable is filtered by its own customized
  # columns _as well as_ the bookmark name, because the bookmark name must always
  # be used in the search.
  #
  # See BaseBookmarkable#search_query for argument docs.
  def perform_search_query(bookmarks, query, ts_query)
    bookmarkable_klass.search_query(bookmarks, query, ts_query) do |bookmarks_joined, where_sql|
      bookmarks_joined.where("#{where_sql} OR bookmarks.name ILIKE :q", q: query)
    end
  end

  ##
  # When displaying the bookmarks in a list for a user there is often additional
  # information drawn from other tables joined to the bookmarkable that must
  # be displayed. We preload these additional associations here on top of the
  # array of bookmarks which has already been filtered, offset by page, ordered,
  # and limited. The preload_associations array should be in the same format as
  # used for .includes() e.g.
  #
  # [{ topic: [:topic_users, :tags] }, :user]
  #
  # For more advanced preloading, bookmarkable classes can implement `perform_custom_preload!`
  #
  # @param [Array] bookmarks The array of bookmarks after initial listing and filtering, note this is
  #                          array _not_ an ActiveRecord::Relation.
  # @return [void]
  def perform_preload(bookmarks, guardian)
    bookmarks_of_type = Bookmark.select_type(bookmarks, bookmarkable_klass.model.to_s)
    return if bookmarks_of_type.empty?

    if bookmarkable_klass.has_preloads?
      ActiveRecord::Associations::Preloader.new(
        records: bookmarks_of_type,
        associations: [bookmarkable: bookmarkable_klass.preload_associations],
      ).call
    end

    bookmarkable_klass.perform_custom_preload!(bookmarks_of_type, guardian)
  end

  def can_send_reminder?(bookmark)
    bookmarkable_klass.reminder_conditions(bookmark)
  end

  def send_reminder_notification(bookmark)
    bookmarkable_klass.reminder_handler(bookmark)
  end

  def can_see?(guardian, bookmark)
    bookmarkable_klass.can_see?(guardian, bookmark)
  end

  def can_see_bookmarkable?(guardian, bookmarkable)
    bookmarkable_klass.can_see_bookmarkable?(guardian, bookmarkable)
  end

  def bookmark_metadata(bookmark, user)
    bookmarkable_klass.bookmark_metadata(bookmark, user)
  end

  def validate_before_create(guardian, bookmarkable)
    bookmarkable_klass.validate_before_create(guardian, bookmarkable)
  end

  def after_create(guardian, bookmark, opts = {})
    bookmarkable_klass.after_create(guardian, bookmark, opts)
  end

  def after_destroy(guardian, bookmark, opts = {})
    bookmarkable_klass.after_destroy(guardian, bookmark, opts)
  end

  def cleanup_deleted
    bookmarkable_klass.cleanup_deleted
  end
end
