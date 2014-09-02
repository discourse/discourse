class SearchPostSerializer < PostSerializer

  has_one :topic, serializer: ListableTopicSerializer

  attributes :blurb
  def blurb
    options[:result].blurb(object)
  end
end
