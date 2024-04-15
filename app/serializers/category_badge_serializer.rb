# frozen_string_literal: true

class CategoryBadgeSerializer < ApplicationSerializer
  attributes :id, :name, :color, :slug, :parent_category_id
end
