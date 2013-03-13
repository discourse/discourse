class CategoryListSerializer < ApplicationSerializer

  attributes :can_create_category

  has_many :categories, serializer: CategoryDetailedSerializer, embed: :objects

  def can_create_category
    scope.can_create?(Category)
  end

end
