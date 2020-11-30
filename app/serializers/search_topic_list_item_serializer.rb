# frozen_string_literal: true

class SearchTopicListItemSerializer < ListableTopicSerializer
  include TopicTagsMixin

  attributes :category_id

  def include_image_url?
    false
  end

  def include_thumbnails?
    false
  end
end
