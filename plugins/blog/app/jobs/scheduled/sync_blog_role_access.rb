# frozen_string_literal: true

module ::Jobs
  # A site's plan can change who may hold the blog roles without any setting
  # being saved, so no event tells the blog to update its categories.
  class SyncBlogRoleAccess < ::Jobs::Scheduled
    every 1.hour

    def execute(args = nil)
      return unless UpcomingChanges.enabled?(:blog_enabled)
      Blog::ManagedCategories.sync_role_access
    end
  end
end
