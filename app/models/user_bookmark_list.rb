# frozen_string_literal: true

class UserBookmarkList
  include ActiveModel::Serialization

  PER_PAGE = 20

  attr_reader :bookmarks, :per_page
  attr_accessor :more_bookmarks_url, :bookmark_serializer_opts

  def initialize(user:, guardian:, params:)
    @user = user
    @guardian = guardian
    @params = params

    @params.merge!(per_page: PER_PAGE) if params[:per_page].blank?
    @params[:per_page] = PER_PAGE if @params[:per_page] > PER_PAGE

    @bookmarks = []
    @bookmark_serializer_opts = {}
  end

  def load(&blk)
    @bookmarks = BookmarkQuery.new(user: @user, guardian: @guardian, params: @params).list_all(&blk)
    @bookmarks
  end

  def per_page
    @per_page ||= @params[:per_page]
  end
end
