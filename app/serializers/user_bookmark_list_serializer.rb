# frozen_string_literal: true

class UserBookmarkListSerializer < ApplicationSerializer
  attributes :more_bookmarks_url

  has_many :bookmarks, serializer: UserBookmarkSerializer, embed: :objects

  def include_more_bookmarks_url?
    object.bookmarks.size == object.per_page
  end
end
