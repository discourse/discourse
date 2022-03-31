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
    topic_results = topic_related_user_bookmarks

    topics = Topic.listable_topics.secured(@guardian)
    pms = Topic.private_messages_for_user(@user)

    topic_results = topic_results.merge(topics.or(pms))
    topic_results = topic_results.merge(Post.secured(@guardian))
    topic_results = @guardian.filter_allowed_categories(topic_results)

    if BookmarkQuery.preloaded_custom_fields.any?
      Topic.preload_custom_fields(
        topic_results, BookmarkQuery.preloaded_custom_fields
      )
    end

    if SiteSetting.use_polymorphic_bookmarks
      results = Bookmark.select("bookmarks.*").from("(#{topic_results.to_sql} UNION #{other_user_bookmarks.to_sql}) as bookmarks")
    else
      results = topic_results
    end

    results = results.order(
      "(CASE WHEN bookmarks.pinned THEN 0 ELSE 1 END),
        bookmarks.reminder_at ASC,
        bookmarks.updated_at DESC"
    )

    if @params[:q].present?
      if SiteSetting.use_polymorphic_bookmarks
        results = polymorphic_search(results, @params[:q])
      else
        results = search(results, @params[:q])
      end
    end

    if @page.positive?
      results = results.offset(@page * @params[:per_page])
    end

    results = results.limit(@limit)

    BookmarkQuery.preload(results, self)
    results
  end

  private

  def other_user_bookmarks
    Bookmark.where(user: @user).where.not(bookmarkable_type: ["Post", "Topic"])
  end

  def topic_related_user_bookmarks
    # There is guaranteed to be a TopicUser record if the user has bookmarked
    # a topic, see BookmarkManager
    if SiteSetting.use_polymorphic_bookmarks
      # FIXME: (martin) How do these joins work with bookmarkable??
      #
      # Oh...these joins will work but somehow need to go via
      # the polymorphic association, should be possible?
      Bookmark.where(user: @user)
        .where(bookmarkable_type: ["Post", "Topic"])
        .joins("LEFT JOIN posts ON posts.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Post'")
        .joins("LEFT JOIN topics ON topics.id = posts.topic_id OR (topics.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Topic')")
        .joins("LEFT JOIN topic_users ON topic_users.topic_id = topics.id")
        .where("topic_users.user_id = ?", @user.id)
    else
      Bookmark.where(user: @user)
        .includes(post: :user)
        .includes(post: { topic: :tags })
        .includes(topic: :topic_users)
        .references(:post)
        .where(topic_users: { user_id: @user.id })
    end
  end

  def search(results, term)
    bookmark_ts_query = Search.ts_query(term: term)
    results
      .joins("LEFT JOIN post_search_data ON post_search_data.post_id = bookmarks.post_id")
      .where("bookmarks.name ILIKE :q OR #{bookmark_ts_query} @@ post_search_data.search_data", q: "%#{term}%")
  end

  def polymorphic_search(results, term)
    bookmark_ts_query = Search.ts_query(term: term)
    results = results
      .joins(
        "LEFT JOIN post_search_data ON post_search_data.post_id = bookmarks.bookmarkable_id
            AND bookmarks.bookmarkable_type = 'Post'"
    )

    #### PLUGIN OUTLET NEEDED HERE
    results = results.joins("LEFT JOIN chat_messages ON chat_messages.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'ChatMessage'")
    ####

    search_sql = ["bookmarks.name ILIKE :q OR #{bookmark_ts_query} @@ post_search_data.search_data"]

    #### PLUGIN OUTLET NEEDED HERE
    search_sql << "chat_messages.message ILIKE :q"
    ####

    results.where(search_sql.join(" OR "), q: "%#{term}%")
  end
end
