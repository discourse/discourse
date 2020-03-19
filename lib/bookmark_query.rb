# frozen_string_literal: true

##
# Allows us to query Bookmark records for lists. Used mainly
# in the user/activity/bookmarks page.

class BookmarkQuery
  cattr_accessor :preloaded_custom_fields
  self.preloaded_custom_fields = Set.new

  def self.on_preload(&blk)
    (@preload ||= Set.new) << blk
  end

  def self.preload(bookmarks, object)
    if @preload
      @preload.each { |preload| preload.call(bookmarks, object) }
    end
  end

  def initialize(user, params = {})
    @user = user
    @params = params
  end

  def list_all
    results = user_bookmarks
      .joins('INNER JOIN topics ON topics.id = bookmarks.topic_id')
      .joins('INNER JOIN posts ON posts.id = bookmarks.post_id')
      .joins('INNER JOIN users ON users.id = posts.user_id')
      .order('bookmarks.created_at DESC')

    if @params[:limit]
      results = results.limit(@params[:limit])
    end

    if BookmarkQuery.preloaded_custom_fields.any?
      Topic.preload_custom_fields(
        results.map(&:topic), BookmarkQuery.preloaded_custom_fields
      )
    end

    BookmarkQuery.preload(results, self)

    results
  end

  private

  def user_bookmarks
    Bookmark.where(user: @user)
      .includes(topic: :tags)
      .includes(post: :user)
  end
end
