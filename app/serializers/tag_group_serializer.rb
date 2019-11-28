# frozen_string_literal: true

class TagGroupSerializer < ApplicationSerializer
  attributes :id, :name, :tag_names, :parent_tag_name, :one_per_topic, :permissions

  def tag_names
    object.tags.base_tags.map(&:name).sort
  end

  def parent_tag_name
    [object.parent_tag.try(:name)].compact
  end

  def permissions
    @permissions ||= begin
      h = {}

      object.tag_group_permissions.joins(:group).includes(:group).find_each do |tgp|
        name = Group::AUTO_GROUP_IDS.fetch(tgp.group_id, tgp.group.name).to_s
        h[name] = tgp.permission_type
      end

      h["everyone"] = TagGroupPermission.permission_types[:full] if h.empty?

      h
    end
  end
end
