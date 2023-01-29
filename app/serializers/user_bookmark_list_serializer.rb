# frozen_string_literal: true

class UserBookmarkListSerializer < ApplicationSerializer
  attributes :more_bookmarks_url, :bookmarks

  def bookmarks
    object.bookmarks.map do |bm|
      bm.registered_bookmarkable.serializer.new(
        bm,
        **object.bookmark_serializer_opts,
        scope: scope,
        root: false,
      )
    end
  end

  def include_more_bookmarks_url?
    @include_more_bookmarks_url ||= object.has_more
  end
end
