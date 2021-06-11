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

  def initialize(user:, guardian: nil, params: {})
    @user = user
    @params = params
    @guardian = guardian || Guardian.new(@user)
    @page = @params[:page].to_i
    @limit = @params[:limit].present? ? @params[:limit].to_i : @params[:per_page]
  end

  def list_all
    results = user_bookmarks.order(
      '(CASE WHEN bookmarks.pinned THEN 0 ELSE 1 END), bookmarks.reminder_at ASC, bookmarks.updated_at DESC'
    )

    topics = Topic.listable_topics.secured(@guardian)
    pms = Topic.private_messages_for_user(@user)
    results = results.merge(topics.or(pms))

    results = results.merge(Post.secured(@guardian))

    if @params[:q].present?
      term = @params[:q]
      bookmark_ts_query = Search.ts_query(term: term)
      results = results
        .joins("LEFT JOIN post_search_data ON post_search_data.post_id = bookmarks.post_id")
        .where(
          "bookmarks.name ILIKE :q OR #{bookmark_ts_query} @@ post_search_data.search_data",
          q: "%#{term}%"
        )
    end

    if @page.positive?
      results = results.offset(@page * @params[:per_page])
    end

    results = results.limit(@limit)

    if BookmarkQuery.preloaded_custom_fields.any?
      Topic.preload_custom_fields(
        results.map(&:topic), BookmarkQuery.preloaded_custom_fields
      )
    end

    BookmarkQuery.preload(results, self)

    @guardian.filter_allowed_categories(results)
  end

  private

  def user_bookmarks
    Bookmark.where(user: @user)
      .includes(topic: :tags)
      .includes(post: :user)
      .references(:topic)
      .references(:post)
  end
end
