# frozen_string_literal: true

class TagGroupCreator
  def self.create(guardian, attributes)
    guardian.ensure_can_admin_tag_groups!
    tag_group = TagGroup.new
    TagGroup.transaction do
      tag_group.assign_attributes(TagGroupUpdater.parameters(attributes))
      raise ActiveRecord::Rollback unless tag_group.save
      StaffActionLogger.new(guardian.user).log_tag_group_create(
        tag_group.name,
        TagGroupSerializer.new(tag_group).to_json(root: false),
      )
    end
    tag_group
  end
end
