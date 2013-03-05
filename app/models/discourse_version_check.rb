class DiscourseVersionCheck

  # include ActiveModel::Model  <-- If we were using Rails 4, we could use this instead of active_attr
  include ActiveAttr::Attributes
  include ActiveAttr::MassAssignment
  include ActiveModel::Serialization

  attr_accessor :latest_version, :critical_updates, :installed_version, :installed_sha, :missing_versions_count

  def active_model_serializer
    DiscourseVersionCheckSerializer
  end

end