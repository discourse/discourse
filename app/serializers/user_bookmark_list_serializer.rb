# frozen_string_literal: true

class UserBookmarkListSerializer < ApplicationSerializer
  attributes :more_bookmarks_url, :bookmarks

  def bookmarks
    if SiteSetting.use_polymorphic_bookmarks
      object.bookmarks.map do |bm|
        case bm.bookmarkable_type
        when "Topic"
          UserTopicBookmarkSerializer.new(bm, object.topics.find { |t| t.id == bm.bookmarkable_id }, scope: scope, root: false)
        when "Post"
          UserPostBookmarkSerializer.new(bm, object.posts.find { |p| p.id == bm.bookmarkable_id }, scope: scope, root: false)
        else
          serialize_registered_type(bm)
        end
      end
    else
      object.bookmarks.map { |bm| UserBookmarkSerializer.new(bm, scope: scope, root: false) }
    end
  end

  def include_more_bookmarks_url?
    @include_more_bookmarks_url ||= object.bookmarks.size == object.per_page
  end

  private

  def serialize_registered_type(bookmark)
    bookmarkable = Bookmark.registered_bookmarkables.find { |bm| bm.model.name == bookmark.bookmarkable_type }
    raise StandardError if !bookmarkable
    preloaded = object.send(bookmarkable.model.table_name).find { |preloaded_data| preloaded_data.id == bookmark.bookmarkable_id }
    bookmarkable.serializer.new(bookmark, preloaded, scope: scope, root: false)
  end
end
