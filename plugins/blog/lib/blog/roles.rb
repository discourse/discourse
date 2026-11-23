# frozen_string_literal: true

module ::Blog
  # The groups that hold each blog role. Nothing else reads the role settings, so
  # a site that may not choose its own roles gets staff in all three, whatever
  # groups it has saved.
  module Roles
    SETTINGS = %i[
      blog_role_groups_enabled
      blog_contributor_groups
      blog_editor_groups
      blog_publisher_groups
    ].freeze

    def self.contributor_group_ids
      group_ids(:blog_contributor_groups)
    end

    def self.editor_group_ids
      group_ids(:blog_editor_groups)
    end

    def self.publisher_group_ids
      group_ids(:blog_publisher_groups)
    end

    def self.editorial_group_ids
      (contributor_group_ids + editor_group_ids + publisher_group_ids).uniq
    end

    def self.group_ids(setting)
      return [Group::AUTO_GROUPS[:staff]] if !SiteSetting.blog_role_groups_enabled
      SiteSetting.public_send(:"#{setting}_map")
    end
    private_class_method :group_ids
  end
end
