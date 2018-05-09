class CategoryAndTopicLists
  include ActiveModel::Serialization
  # http://api.rubyonrails.org/v5.0/classes/ActiveModel/Serialization.html

  attr_accessor :category_list, :topic_list
end
