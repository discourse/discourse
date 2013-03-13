class CategoryTopicSerializer < BasicTopicSerializer

  attributes :slug,
             :visible,
             :closed,
             :archived

  has_one :category

end
