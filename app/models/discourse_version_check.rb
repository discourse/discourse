# frozen_string_literal: true

class DiscourseVersionCheck
  include ActiveModel::Model

  attr_accessor :latest_version,
                :critical_updates,
                :installed_version,
                :installed_sha,
                :installed_describe,
                :missing_versions_count,
                :git_branch,
                :updated_at,
                :version_check_pending,
                :stale_data
end
