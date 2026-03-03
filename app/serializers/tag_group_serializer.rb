# frozen_string_literal: true

class TagGroupSerializer < ApplicationSerializer
  attributes :id, :name, :tags, :parent_tag, :one_per_topic, :permissions

  def tags
    object.tags.base_tags.order(:name).map { |t| { id: t.id, name: t.name, slug: t.slug_for_url } }
  end

  def parent_tag
    return [] unless object.parent_tag
    [
      {
        id: object.parent_tag.id,
        name: object.parent_tag.name,
        slug: object.parent_tag.slug_for_url,
      },
    ]
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
