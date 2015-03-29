class SearchPostSerializer < PostSerializer

  has_one :topic, serializer: TopicListItemSerializer

  attributes :blurb
  def blurb
    options[:result].blurb(object)
  end
end
