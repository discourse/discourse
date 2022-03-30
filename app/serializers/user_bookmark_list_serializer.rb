# frozen_string_literal: true

class UserBookmarkListSerializer < ApplicationSerializer
  attributes :more_bookmarks_url, :bookmarks

  def bookmarks
    object.bookmarks.map do |bm|
      case bm.bookmarkable_type
      when "Topic"
        UserTopicBookmarkSerializer.new(bm, object.topics.find { |t| t.id == bm.bookmarkable_id }, scope: scope, root: false)
      when "Post"
        UserPostBookmarkSerializer.new(bm, object.posts.find { |p| p.id == bm.bookmarkable_id }, scope: scope, root: false)
      when "ChatMessage"
        UserChatMessageBookmarkSerializer.new(bm, object.chat_messages.find { |cm| cm.id == bm.bookmarkable_id }, scope: scope, root: false)
      end
    end
  end

  def include_more_bookmarks_url?
    @include_more_bookmarks_url ||= object.bookmarks.size == object.per_page
  end
end
