# frozen_string_literal: true

class UserBookmarkListSerializer < ApplicationSerializer
  attributes :more_bookmarks_url, :bookmarks

  has_many :categories, serializer: CategoryBadgeSerializer, embed: :objects

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

  def include_categories?
    scope.can_lazy_load_categories?
  end
end
