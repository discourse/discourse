# frozen_string_literal: true

class TagGroupSerializer < ApplicationSerializer
  attributes :id, :name, :tags, :parent_tag, :one_per_topic, :permissions

  def tags
    object
      .tags
      .base_tags
      .map { |tag| { id: tag.id, name: tag.name, slug: tag.slug } }
      .sort_by { |t| t[:name] }
  end

  def parent_tag
    return [] unless object.parent_tag
    [{ id: object.parent_tag.id, name: object.parent_tag.name, slug: object.parent_tag.slug }]
  end

  def permissions
    @permissions ||=
      begin
        h = object.tag_group_permissions.pluck(:group_id, :permission_type).to_h
        h[0] = TagGroupPermission.permission_types[:full] if h.empty?
        h
      end
  end
end
