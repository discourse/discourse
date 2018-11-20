class SearchTopicListItemSerializer < ListableTopicSerializer
  include TopicTagsMixin

  attributes :category_id
end
