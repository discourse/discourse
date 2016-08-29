class CategoryAndTopicListsSerializer < ApplicationSerializer
  has_one :category_list, serializer: CategoryListSerializer, embed: :objects
  has_one :topic_list, serializer: TopicListSerializer, embed: :objects
end
