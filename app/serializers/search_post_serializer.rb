class SearchPostSerializer < BasicPostSerializer
  has_one :topic, serializer: TopicListItemSerializer

  attributes :like_count, :blurb, :post_number

  def blurb
    object.blurb.to_str
  end
end
