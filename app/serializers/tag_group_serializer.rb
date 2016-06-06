class TagGroupSerializer < ApplicationSerializer
  attributes :id, :name, :tag_names

  def tag_names
    object.tags.pluck(:name).sort
  end
end
