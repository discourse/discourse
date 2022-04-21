# frozen_string_literal: true
#
# Should only be created via the Bookmark.register_bookmarkable
# method; this is used to let the BookmarkQuery class query and
# search additional bookmarks for the user bookmark list, and
# also to enumerate on the registered Bookmarkable types.
#
# Post and Topic bookmarkables are registered by default.
#
# Anything other than types registered in this way will throw an error
# when trying to save the Bookmark record. All things that are bookmarkable
# must be registered in this way.
class Bookmarkable
  attr_reader :model, :serializer, :list_query, :search_query, :preload_associations
  delegate :table_name, to: :@model

  def initialize(model:, serializer:, list_query:, search_query:, preload_associations: [])
    @model = model
    @serializer = serializer
    @list_query = list_query
    @search_query = search_query
    @preload_associations = preload_associations
  end

  def perform_list_query(user, guardian)
    list_query.call(user, guardian)
  end

  def perform_search_query(bookmarks, query, ts_query)
    search_query.call(bookmarks, query, ts_query) do |bookmarks_joined, where_sql|
      bookmarks_joined.where("#{where_sql} OR bookmarks.name ILIKE :q", q: query)
    end
  end

  def perform_preload(bookmarks)
    ActiveRecord::Associations::Preloader.new.preload(
      Bookmark.select_type(bookmarks, model.to_s), { bookmarkable: preload_associations }
    )
  end
end
