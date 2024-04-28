# frozen_string_literal: true

module SecureUploadEndpointHelpers
  include ActiveSupport::Concern

  def upload_from_path_and_extension(path_with_ext)
    sha1 = File.basename(path_with_ext, File.extname(path_with_ext))
    # this takes care of optimized image requests
    sha1 = sha1.partition("_").first if sha1.include?("_")
    Upload.find_by(sha1: sha1)
  end

  def upload_from_full_url(url)
    Upload.find_by(sha1: Upload.sha1_from_long_url(url))
  end

  def check_secure_upload_permission(upload)
    if upload.access_control_post_id.present?
      raise Discourse::InvalidAccess if current_user.nil? && SiteSetting.login_required
      raise Discourse::InvalidAccess if !guardian.can_see?(upload.access_control_post)
    else
      raise Discourse::NotFound if current_user.nil?
    end
  end
end
