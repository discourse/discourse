# frozen_string_literal: true

class UserBookmarkList
  include ActiveModel::Serialization

  PER_PAGE = 20

  attr_reader :bookmarks
  attr_accessor :more_bookmarks_url

  def initialize(user:, guardian:, params:)
    @user = user
    @guardian = guardian
    @params = params.merge(per_page: PER_PAGE)
    @bookmarks = []
  end

  def load
    @bookmarks = BookmarkQuery.new(user: @user, guardian: @guardian, params: @params).list_all
    @bookmarks
  end

  def per_page
    @per_page ||= PER_PAGE
  end
end
