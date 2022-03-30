# frozen_string_literal: true

class UserBookmarkList
  include ActiveModel::Serialization

  PER_PAGE = 20

  attr_reader :bookmarks, :per_page, :posts, :topics, :chat_messages
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
    preload_polymorphic_associations
    @bookmarks
  end

  def per_page
    @per_page ||= @params[:per_page]
  end

  private

  # we have already confirmed the user has access to these records at
  # this point in BookmarkQuery, so it is safe to load them directly
  def preload_polymorphic_associations
    @topics = Topic.where(id: @bookmarks.select { |bm| bm.bookmarkable_type == "Topic" }.map(&:bookmarkable_id)).includes(
      :topic_user
    ).where(topic_users: { user_id: @user.id })
    @posts = Post.where(id: @bookmarks.select { |bm| bm.bookmarkable_type == "Post" }.map(&:bookmarkable_id)).includes(
      topic: :topic_users
    ).where(topic_users: { user_id: @user.id })

    # needs to probably be a plugin hook or some other way of loading these associations,
    # maybe just .map'ing all the :bookmarkable records directly?
    @chat_messages = ChatMessage.where(
      id: @bookmarks.select { |bm| bm.bookmarkable_type == "ChatMessage" }.map(&:bookmarkable_id)
    ).includes(:chat_channel)
  end
end
