class DiscourseVersionCheckSerializer < ApplicationSerializer
  attributes :latest_version,
             :critical_updates,
             :installed_version,
             :installed_sha,
             :missing_versions_count,
             :updated_at

  self.root = false
end
