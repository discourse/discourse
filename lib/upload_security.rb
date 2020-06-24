# frozen_string_literal: true

##
# A note on determining whether an upload should be marked as secure:
#
# Some of these flags checked (e.g. all of the for_X flags and the opts[:type])
# are only set when _initially uploading_ via UploadCreator and are not present
# when an upload already exists.
#
# If the upload already exists the best way to figure out whether it should be
# secure alongside the site settings is the access_control_post_id, because the
# original post the upload is linked to has far more bearing on its security context
# post-upload. If the access_control_post_id does not exist then we just rely
# on the current secure? status, otherwise there would be a lot of additional
# complex queries and joins to perform.
class UploadSecurity
  PUBLIC_TYPES = %w[avatar custom_emoji profile_background card_background]
  def initialize(upload, opts = {})
    @upload = upload
    @opts = opts
    @upload_type = @opts[:type]
  end

  def should_be_secure?
    return false if !SiteSetting.secure_media?
    return false if uploading_in_public_context?
    uploading_in_secure_context?
  end

  private

  def uploading_in_public_context?
    @upload.for_theme || @upload.for_site_setting || @upload.for_gravatar || public_type? || used_for_custom_emoji? || based_on_regular_emoji?
  end

  def uploading_in_secure_context?
    return true if SiteSetting.login_required?
    if @upload.access_control_post_id.present?
      return access_control_post_has_secure_media?
    end
    uploading_in_composer? || @upload.for_private_message || @upload.for_group_message || @upload.secure?
  end

  # whether the upload should remain secure or not after posting depends on its context,
  # which is based on the post it is linked to via access_control_post_id.
  # if that post is with_secure_media? then the upload should also be secure.
  # this may change to false if the upload was set to secure on upload e.g. in
  # a post composer then it turned out that the post itself was not in a secure context
  #
  # if there is no access control post id and the upload is currently secure, we
  # do not want to make it un-secure to avoid unintentionally exposing it
  def access_control_post_has_secure_media?
    @upload.access_control_post.with_secure_media?
  end

  def public_type?
    PUBLIC_TYPES.include?(@upload_type)
  end

  def uploading_in_composer?
    @upload_type == "composer"
  end

  def used_for_custom_emoji?
    @upload.id.present? && CustomEmoji.exists?(upload_id: @upload.id)
  end

  def based_on_regular_emoji?
    return false if @upload.origin.blank?
    uri = URI.parse(@upload.origin)
    return true if Emoji.all.map(&:url).include?("#{uri.path}?#{uri.query}")
    uri.path.include?("images/emoji")
  end
end
