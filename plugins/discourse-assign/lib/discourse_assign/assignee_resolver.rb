# frozen_string_literal: true

module DiscourseAssign
  module AssigneeResolver
    def self.resolve!(guardian, username: nil, group_name: nil)
      username = username.to_s.strip.presence
      group_name = group_name.to_s.strip.presence

      raise Discourse::InvalidParameters.new(:assignee) if username.blank? && group_name.blank?

      return User.find_by_username(username) || raise(Discourse::NotFound) if username

      group = Group.find_by("LOWER(name) = ?", group_name.downcase)
      raise Discourse::NotFound if group.blank?
      guardian.ensure_can_see_group!(group)

      group
    end
  end
end
