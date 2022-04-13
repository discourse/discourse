# frozen_string_literal: true

class UserBookmarkListSerializer < ApplicationSerializer
  attributes :more_bookmarks_url, :bookmarks

  def bookmarks
    if SiteSetting.use_polymorphic_bookmarks
      object.bookmarks.map do |bm|
        case bm.bookmarkable_type
        when "Topic"
          UserTopicBookmarkSerializer.new(bm, scope: scope, root: false)
        when "Post"
          UserPostBookmarkSerializer.new(bm, scope: scope, root: false)
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
    bookmarkable.serializer.new(bookmark, scope: scope, root: false)
  end
end
