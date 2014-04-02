class DiscourseVersionCheck
  include ActiveModel::Model
  include ActiveModel::SerializerSupport

  attr_accessor :latest_version, :critical_updates, :installed_version, :installed_sha, :missing_versions_count, :updated_at, :version_check_pending
end
