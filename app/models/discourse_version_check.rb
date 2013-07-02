class DiscourseVersionCheck

  include ActiveModel::Model
  include ActiveModel::Serialization

  attr_accessor :latest_version, :critical_updates, :installed_version, :installed_sha, :missing_versions_count, :updated_at

  def active_model_serializer
    DiscourseVersionCheckSerializer
  end

end