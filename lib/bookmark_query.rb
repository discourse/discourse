# frozen_string_literal: true

##
# Allows us to query Bookmark records for lists. Used mainly
# in the user/activity/bookmarks page.

class BookmarkQuery
  def self.on_preload(&blk)
    (@preload ||= Set.new) << blk
  end

  def self.preload(bookmarks, object)
    if SiteSetting.use_polymorphic_bookmarks
      preload_polymorphic_associations(bookmarks)
    end
    if @preload
      @preload.each { |preload| preload.call(bookmarks, object) }
    end
  end

  # These polymorphic associations are loaded to make the UserBookmarkListSerializer's
  # life easier, which conditionally chooses the bookmark serializer to use based
  # on the type, and we want the associations all loaded ahead of time to make
  # sure we are not doing N+1s.
  def self.preload_polymorphic_associations(bookmarks)
    ActiveRecord::Associations::Preloader.new.preload(
      Bookmark.select_type(bookmarks, "Topic"), { bookmarkable: [:topic_users, :posts] }
    )

    ActiveRecord::Associations::Preloader.new.preload(
      Bookmark.select_type(bookmarks, "Post"), { bookmarkable: [{ bookmarkable_relation: :topic_users }] }
    )

    Bookmark.registered_bookmarkables.each do |registered_bookmarkable|
      registered_bookmarkable.preload_associations(bookmarks)
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
    topics = Topic.listable_topics.secured(@guardian)
    pms = Topic.private_messages_for_user(@user)

    # A note about the difference in queries here...pre-polymorphic bookmarks are
    # all attached to a post so both the Post.secured filter and the topics/pms/allowed
    # category filters all work correctly. However with polymorphic bookmarks, the
    # bookmarks could be attached to any relation, so we must get the post and
    # topic bookmarks separately and apply the relevant filters to them directly.
    #
    # Much of the complexity in this file will be cleaned up when we switch completely
    # to polymorphic bookmakrks.
    if SiteSetting.use_polymorphic_bookmarks
      results = list_all_results_polymorphic(topics, pms)
    else
      results = list_all_results(topics, pms)
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

    results = results.limit(@limit).to_a
    BookmarkQuery.preload(results, self)
    results
  end

  private

  def list_all_results(topics, pms)
    results = base_bookmarks.merge(topics.or(pms))
    results = results.merge(Post.secured(@guardian))
    results = @guardian.filter_allowed_categories(results)
    results
  end

  def list_all_results_polymorphic(topics, pms)
    topic_results = topic_bookmarks.merge(topics.or(pms))

    post_results = post_bookmarks.merge(topics.or(pms))
    post_results = post_results.merge(Post.secured(@guardian))

    topic_results = @guardian.filter_allowed_categories(topic_results)
    post_results = @guardian.filter_allowed_categories(post_results)

    # TODO: At some point we may want to introduce ways for other Bookmarkable types
    # to further filter results securely using merges, though this is not necessary just
    # yet.

    union_sql = "#{topic_results.to_sql} UNION #{post_results.to_sql}"
    if Bookmark.registered_bookmarkables.any?
      union_sql += " UNION #{other_bookmarks.to_sql}"
    end
    Bookmark.select("bookmarks.*").from("(#{union_sql}) as bookmarks")
  end

  def base_bookmarks
    Bookmark.where(user: @user)
      .includes(post: :user)
      .includes(post: { topic: :tags })
      .includes(topic: :topic_users)
      .references(:post)
      .where(topic_users: { user_id: @user.id })
  end

  def base_bookmarks_polymorphic
    Bookmark.where(user: @user)
      .joins("LEFT JOIN posts ON posts.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Post'")
      .joins("LEFT JOIN topics ON topics.id = posts.topic_id OR (topics.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Topic')")
      .joins("LEFT JOIN topic_users ON topic_users.topic_id = topics.id")
      .where("topic_users.user_id = ?", @user.id)
  end

  def topic_bookmarks
    base_bookmarks_polymorphic.where(bookmarkable_type: "Topic")
  end

  def post_bookmarks
    base_bookmarks_polymorphic.where(bookmarkable_type: "Post")
  end

  def other_bookmarks
    Bookmark.where(user: @user).where.not(bookmarkable_type: Bookmark::SPECIAL_BOOKMARKABLE_TYPES)
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

    search_sql = ["bookmarks.name ILIKE :q OR #{bookmark_ts_query} @@ post_search_data.search_data"]
    Bookmark.registered_bookmarkables.each do |bm|
      results = bm.search_join(results)
      search_sql << bm.search_filters
    end

    results.where(search_sql.flatten.join(" OR "), q: "%#{term}%")
  end
end
