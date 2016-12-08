class TagGroupSerializer < ApplicationSerializer
  attributes :id, :name, :tag_names, :parent_tag_name, :one_per_topic

  def tag_names
    object.tags.map(&:name).sort
  end

  def parent_tag_name
    [object.parent_tag.try(:name)].compact
  end
end
