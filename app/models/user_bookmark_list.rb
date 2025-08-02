# frozen_string_literal: true

class UserBookmarkList
  include ActiveModel::Serialization

  PER_PAGE = 20

  attr_reader :bookmarks, :per_page, :has_more
  attr_accessor :more_bookmarks_url, :bookmark_serializer_opts

  def initialize(user:, guardian:, search_term: nil, per_page: nil, page: 0)
    @user = user
    @guardian = guardian

    @per_page = per_page || PER_PAGE
    @per_page = PER_PAGE if @per_page > PER_PAGE

    @search_term = search_term
    @page = page.to_i

    @bookmarks = []
    @bookmark_serializer_opts = {}
  end

  def load(&blk)
    query =
      BookmarkQuery.new(
        user: @user,
        guardian: @guardian,
        search_term: @search_term,
        page: @page,
        per_page: @per_page,
      )

    @bookmarks = query.list_all(&blk)
    @has_more = (@page.to_i + 1) * @per_page < query.count
    @bookmarks
  end

  def categories
    @categories ||=
      @bookmarks
        .map do |bm|
          category = bm.bookmarkable.try(:category) || bm.bookmarkable.try(:topic)&.category
          [category&.parent_category, category]
        end
        .flatten
        .compact
        .uniq
  end
end
