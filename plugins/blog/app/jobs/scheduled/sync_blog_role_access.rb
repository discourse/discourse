# frozen_string_literal: true

module ::Jobs
  class SyncBlogRoleAccess < ::Jobs::Scheduled
    every 1.hour

    def execute(args = nil)
      return unless UpcomingChanges.enabled?(:blog_enabled)
      Blog::ManagedCategories.sync_role_access
    end
  end
end
