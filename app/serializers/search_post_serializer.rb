class SearchPostSerializer < BasicPostSerializer
  has_one :topic, serializer: TopicListItemSerializer

  attributes :like_count, :blurb

  def blurb
    options[:result].blurb(object)
  end
end
