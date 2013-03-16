class CategoryTopicSerializer < ListableTopicSerializer

  attributes :visible, :closed, :archived
  has_one :category

end
