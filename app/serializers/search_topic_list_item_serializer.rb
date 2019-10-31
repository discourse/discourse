# frozen_string_literal: true

class SearchTopicListItemSerializer < ListableTopicSerializer
  root 'search_topic_list_item'

  include TopicTagsMixin

  attributes :category_id
end
