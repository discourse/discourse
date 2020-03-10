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
      .select(<<-SQL
        bookmarks.id, bookmarks.name AS bookmark_name, bookmarks.reminder_at AS bookmark_reminder_at,
        bookmarks.created_at, bookmarks.post_id, bookmarks.topic_id, posts.post_number AS bookmark_post_number,
        topics.title, topics.closed AS topic_closed, topics.archived AS topic_archived,
        CASE WHEN coalesce(posts.deleted_at, topics.deleted_at) IS NULL THEN false ELSE true END deleted,
        posts.hidden, topics.category_id, topics.archetype, topics.highest_post_number,
        topics.bumped_at, posts.raw, posts.cooked, topics.slug
        SQL
      ).order('created_at DESC')

    if @params[:limit]
      results = results.limit(@params[:limit])
    end

    results
  end

  private

  def user_bookmarks
    Bookmark.where(user: @user)
  end
end
