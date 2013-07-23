class DiscourseVersionCheck
  if rails4?
    include ActiveModel::Model
  else
    include ActiveAttr::Attributes
    include ActiveAttr::MassAssignment
    include ActiveModel::Serialization
  end

  attr_accessor :latest_version, :critical_updates, :installed_version, :installed_sha, :missing_versions_count, :updated_at

  def active_model_serializer
    DiscourseVersionCheckSerializer
  end

end