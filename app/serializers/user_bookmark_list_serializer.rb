# frozen_string_literal: true

class UserBookmarkListSerializer < ApplicationSerializer
  attributes :more_bookmarks_url, :bookmarks

  def bookmarks
    if SiteSetting.use_polymorphic_bookmarks
      object.bookmarks.map do |bm|
        serialize_registered_type(bm)
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
    Bookmark.registered_bookmarkable_from_type(
      bookmark.bookmarkable_type
    ).serializer.new(bookmark, scope: scope, root: false)
  end
end
