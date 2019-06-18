# frozen_string_literal: true

class SearchPostSerializer < BasicPostSerializer
  has_one :topic, serializer: SearchTopicListItemSerializer

  attributes :like_count, :blurb, :post_number

  def blurb
    options[:result].blurb(object)
  end

  def include_cooked?
    false
  end

  def include_ignored?
    false
  end
end
