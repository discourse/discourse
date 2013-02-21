class CategoryTopicSerializer < BasicTopicSerializer

  attributes :slug,
             :visible, 
             :pinned, 
             :closed, 
             :archived

  has_one :category

end
