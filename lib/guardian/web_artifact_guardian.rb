# frozen_string_literal: true

module WebArtifactGuardian
  def can_create_web_artifact?
    is_admin? || @user&.in_any_groups?(SiteSetting.web_artifact_allowed_groups_map)
  end

  def can_view_web_artifact?(artifact)
    return false if artifact.post_id.nil? && !artifact.public?
    artifact.public? || can_see?(artifact.post)
  end

  def can_edit_web_artifact?(artifact)
    return false unless authenticated?
    is_admin? || artifact.user_id == @user.id
  end

  def can_delete_web_artifact?(artifact)
    can_edit_web_artifact?(artifact)
  end
end
