# frozen_string_literal: true

class UserBookmarkList
  include ActiveModel::Serialization

  PER_PAGE = 20

  attr_reader :bookmarks, :per_page, :posts, :topics
  attr_accessor :more_bookmarks_url

  def initialize(user:, guardian:, params:)
    @user = user
    @guardian = guardian
    @params = params

    @params.merge!(per_page: PER_PAGE) if params[:per_page].blank?
    @params[:per_page] = PER_PAGE if @params[:per_page] > PER_PAGE

    @bookmarks = []
  end

  def load
    @bookmarks = BookmarkQuery.new(user: @user, guardian: @guardian, params: @params).list_all
    if SiteSetting.use_polymorphic_bookmarks
      preload_polymorphic_associations
    end
    @bookmarks
  end

  def per_page
    @per_page ||= @params[:per_page]
  end

  private

  # We have already confirmed the user has access to these records at
  # this point in BookmarkQuery, so it is safe to load them directly
  # without any further security checks.
  #
  # These polymorphic associations are loaded to make the UserBookmarkListSerializer's
  # life easier, which conditionally chooses the bookmark serializer to use based
  # on the type, and we want the associations all loaded ahead of time to make
  # sure we are not doing N1s.
  def preload_polymorphic_associations
    @topics = Topic.includes(:topic_users).where(
      id: Bookmark.select_type(@bookmarks, "Topic").map(&:bookmarkable_id)
    ).where(topic_users: { user_id: @user.id })

    @posts = Post.includes(topic: :topic_users).where(
      id: Bookmark.select_type(@bookmarks, "Post").map(&:bookmarkable_id)
    ).where(topic_users: { user_id: @user.id })

    Bookmark.registered_bookmarkables.each do |registered_bookmarkable|
      bookmarkable_ids = Bookmark.select_type(@bookmarks, registered_bookmarkable.model.name).map(&:bookmarkable_id)
      self.instance_variable_set(
        :"@#{registered_bookmarkable.table_name}",
        registered_bookmarkable.preload_associations(bookmarkable_ids)
      )
      self.class.send(:attr_reader, registered_bookmarkable.table_name)
    end
  end
end
