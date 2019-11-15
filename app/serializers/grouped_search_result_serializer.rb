# frozen_string_literal: true

class GroupedSearchResultSerializer < ApplicationSerializer
  has_many :posts, serializer: SearchPostSerializer
  has_many :users, serializer: SearchResultUserSerializer
  has_many :categories, serializer: BasicCategorySerializer
  has_many :tags, serializer: TagSerializer
  has_many :groups, serializer: BasicGroupSerializer
  attributes :more_posts, :more_users, :more_categories, :term, :search_log_id, :more_full_page_results, :can_create_topic, :error

  def search_log_id
    object.search_log_id
  end

  def include_search_log_id?
    search_log_id.present?
  end

  def include_tags?
    SiteSetting.tagging_enabled
  end

  def can_create_topic
    scope.can_create?(Topic)
  end

end
