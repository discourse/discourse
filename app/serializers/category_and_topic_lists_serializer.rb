# frozen_string_literal: true

class CategoryAndTopicListsSerializer < ApplicationSerializer
  has_one :category_list, serializer: CategoryListSerializer, embed: :objects
  has_one :topic_list, serializer: TopicListSerializer, embed: :objects
  has_many :users, serializer: PosterSerializer, embed: :objects
  has_many :primary_groups, serializer: PrimaryGroupSerializer, embed: :objects

  def users
    users = object.topic_list.topics.map { |t| t.posters.map { |poster| poster.try(:user) } }
    users.flatten!
    users.compact!
    users.uniq!(&:id)
    users
  end

  def primary_groups
    groups =
      object.topic_list.topics.map { |t| t.posters.map { |poster| poster.try(:primary_group) } }
    groups.flatten!
    groups.compact!
    groups.uniq!(&:id)
    groups
  end
end
