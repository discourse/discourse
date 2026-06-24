# frozen_string_literal: true

class DiscourseVersionCheckSerializer < ApplicationSerializer
  attributes :latest_version,
             :latest_pretty_version,
             :latest_sha,
             :critical_updates,
             :installed_version,
             :installed_sha,
             :installed_describe,
             :missing_versions_count,
             :updated_at

  self.root = false
end
