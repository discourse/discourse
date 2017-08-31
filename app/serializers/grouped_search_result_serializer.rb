class GroupedSearchResultSerializer < ApplicationSerializer
  has_many :posts, serializer: SearchPostSerializer
  has_many :users, serializer: SearchResultUserSerializer
  has_many :categories, serializer: BasicCategorySerializer
  has_many :tags, serializer: TagSerializer
  attributes :more_posts, :more_users, :more_categories, :term, :search_log_id, :more_full_page_results

  def search_log_id
    object.search_log_id
  end

  def include_search_log_id?
    search_log_id.present?
  end

  def include_tags?
    SiteSetting.tagging_enabled
  end

end
