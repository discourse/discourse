# frozen_string_literal: true

class CategoryRequiredTagGroupSerializer < ApplicationSerializer
  attributes :name, :min_count

  def name
    object.tag_group&.name
  end
end
