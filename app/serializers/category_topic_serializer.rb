class CategoryTopicSerializer < BasicTopicSerializer

  attributes :slug

  has_one :category

end
