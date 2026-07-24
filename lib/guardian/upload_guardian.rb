# frozen_string_literal: true

module UploadGuardian
  def can_see_upload?(upload)
    return !upload.secure? if upload.access_control_post_id.blank?
    can_see_post?(upload.access_control_post)
  end
end
