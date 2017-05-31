class SearchPostSerializer < BasicPostSerializer
  has_one :topic, serializer: SearchTopicListItemSerializer

  attributes :like_count, :blurb, :post_number

  def blurb
    options[:result].blurb(object)
  end
end
