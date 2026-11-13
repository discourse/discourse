# frozen_string_literal: true

class TagGroupSerializer < ApplicationSerializer
  attributes :id, :name, :tags, :parent_tag, :one_per_topic, :permissions

  def tags
    tags = object.base_tags
    tags = tags.loaded? ? tags.sort_by(&:name) : tags.order(:name)
    tags.map { |t| { id: t.id, name: t.name, slug: t.slug_for_url } }
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
        permissions = object.tag_group_permissions
        h =
          if permissions.loaded?
            permissions.to_h { |permission| [permission.group_id, permission.permission_type] }
          else
            permissions.pluck(:group_id, :permission_type).to_h
          end
        h[0] = TagGroupPermission.permission_types[:full] if h.empty?
        h
      end
  end
end
