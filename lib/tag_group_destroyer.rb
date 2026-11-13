# frozen_string_literal: true

class TagGroupDestroyer
  def self.destroy(guardian, tag_group)
    guardian.ensure_can_admin_tag_groups!
    TagGroup.transaction do
      tag_group.lock!
      data = TagGroupSerializer.new(tag_group).to_json(root: false)
      tag_group.destroy!
      StaffActionLogger.new(guardian.user).log_tag_group_destroy(tag_group.name, data)
    end
    tag_group
  end
end
