# frozen_string_literal: true

class UserBookmarkList
  include ActiveModel::Serialization

  PER_PAGE = 20

  attr_reader :bookmarks, :per_page, :has_more
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
    query = BookmarkQuery.new(user: @user, guardian: @guardian, params: @params)
    @bookmarks = query.list_all(&blk)
    @has_more = (@params[:page].to_i + 1) * @params[:per_page] < query.count
    @bookmarks
  end

  def per_page
    @per_page ||= @params[:per_page]
  end
end
