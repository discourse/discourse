# frozen_string_literal: true

class UserBookmarkListSerializer < ApplicationSerializer
  attributes :more_bookmarks_url, :bookmarks

  def bookmarks
    if SiteSetting.use_polymorphic_bookmarks
      object.bookmarks.map do |bm|
        bm.registered_bookmarkable.serializer.new(bm, scope: scope, root: false)
      end
    else
      object.bookmarks.map { |bm| UserBookmarkSerializer.new(bm, scope: scope, root: false) }
    end
  end

  def include_more_bookmarks_url?
    @include_more_bookmarks_url ||= object.bookmarks.size == object.per_page
  end
end
