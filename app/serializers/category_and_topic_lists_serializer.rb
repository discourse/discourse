class CategoryAndTopicListsSerializer < ApplicationSerializer
  has_one :category_list, serializer: CategoryListSerializer, embed: :objects
  has_one :topic_list, serializer: TopicListSerializer, embed: :objects
  has_many :users, serializer: BasicUserSerializer, embed: :objects

  def users
    users = object.topic_list.topics.map do |t|
      t.posters.map { |poster| poster.try(:user) }
    end
    users.flatten!
    users.compact!
    users.uniq!(&:id)
    users
  end

end
