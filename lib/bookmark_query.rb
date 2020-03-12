# frozen_string_literal: true

##
# Allows us to query Bookmark records for lists. Used mainly
# in the user/activity/bookmarks page.

class BookmarkQuery
  def initialize(user, params)
    @user = user
    @params = params
  end

  def list_all
    results = user_bookmarks
      .joins('INNER JOIN topics ON topics.id = bookmarks.topic_id')
      .joins('INNER JOIN posts ON posts.id = bookmarks.post_id')
      .joins('INNER JOIN users ON users.id = posts.user_id')
      .order('created_at DESC')

    if @params[:limit]
      results = results.limit(@params[:limit])
    end

    results
  end

  private

  def user_bookmarks
    Bookmark.where(user: @user).includes(:topic).includes(post: :user)
  end
end
