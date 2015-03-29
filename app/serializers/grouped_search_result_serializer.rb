class GroupedSearchResultSerializer < ApplicationSerializer
  has_many :posts, serializer: SearchPostSerializer
  has_many :users, serializer: BasicUserSerializer
  has_many :categories, serializer: BasicCategorySerializer
  attributes :more_posts, :more_users, :more_categories
end
