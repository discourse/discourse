class CategoryListSerializer < ApplicationSerializer

  attributes :can_create_category,
             :can_create_topic,
             :draft,
             :draft_key,
             :draft_sequence

  has_many :categories, serializer: CategoryDetailedSerializer, embed: :objects

  def can_create_category
    scope.can_create?(Category)
  end

  def can_create_topic
    false
  end

end
