class DiscourseVersionCheck
  include ActiveModel::Model

  attr_accessor :latest_version, :critical_updates, :installed_version, :installed_sha, :installed_describe, :missing_versions_count, :updated_at, :version_check_pending
end
