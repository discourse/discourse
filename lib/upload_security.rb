# frozen_string_literal: true

##
# A note on determining whether an upload should be marked as secure:
#
# Some of these flags checked (e.g. all of the for_X flags and the opts[:type])
# are only set when _initially uploading_ via UploadCreator and are not present
# when an upload already exists, these will only be checked when the @creating
# option is present.
#
# If the upload already exists the best way to figure out whether it should be
# secure alongside the site settings is the access_control_post_id, because the
# original post the upload is linked to has far more bearing on its security context
# post-upload. If the access_control_post_id does not exist then we just rely
# on the current secure? status, otherwise there would be a lot of additional
# complex queries and joins to perform. Over time more of these specific
# queries will be implemented.
class UploadSecurity
  @@custom_public_types = []

  PUBLIC_TYPES = %w[
    avatar
    custom_emoji
    profile_background
    card_background
    category_logo
    category_background
    group_flair
    badge_image
  ]

  def self.register_custom_public_type(type)
    @@custom_public_types << type if !@@custom_public_types.include?(type)
  end

  # used in tests
  def self.reset_custom_public_types
    @@custom_public_types = []
  end

  def initialize(upload, opts = {})
    @upload = upload
    @opts = opts
    @upload_type = @opts[:type]
    @creating = @opts[:creating]
  end

  def should_be_secure?
    should_be_secure_with_reason.first
  end

  def should_be_secure_with_reason
    insecure_context_checks.each do |check, reason|
      return [false, reason] if perform_check(check)
    end
    secure_context_checks.each do |check, reason|
      return [perform_check(check), reason] if priority_check?(check)
      return [true, reason] if perform_check(check)
    end

    [false, "no checks satisfied"]
  end

  def secure_media_disabled_check
    !SiteSetting.secure_media?
  end

  def insecure_creation_for_modifiers_check
    return false if !@creating
    @upload.for_theme || @upload.for_site_setting || @upload.for_gravatar
  end

  def public_type_check
    PUBLIC_TYPES.include?(@upload_type) || @@custom_public_types.include?(@upload_type)
  end

  def custom_emoji_check
    @upload.id.present? && CustomEmoji.exists?(upload_id: @upload.id)
  end

  def regular_emoji_check
    return false if @upload.origin.blank?
    uri = URI.parse(@upload.origin)
    return true if Emoji.all.map(&:url).include?("#{uri.path}?#{uri.query}")
    uri.path.include?("images/emoji")
  end

  def login_required_check
    SiteSetting.login_required?
  end

  # whether the upload should remain secure or not after posting depends on its context,
  # which is based on the post it is linked to via access_control_post_id.
  # if that post is with_secure_media? then the upload should also be secure.
  # this may change to false if the upload was set to secure on upload e.g. in
  # a post composer then it turned out that the post itself was not in a secure context
  #
  # a post is with secure media if it is a private message or in a read restricted
  # category
  def access_control_post_has_secure_media_check
    access_control_post&.with_secure_media?
  end

  def uploading_in_composer_check
    @upload_type == "composer"
  end

  def secure_creation_for_modifiers_check
    return false if !@creating
    @upload.for_private_message || @upload.for_group_message
  end

  def already_secure_check
    @upload.secure?
  end

  private

  def access_control_post
    @access_control_post ||= @upload.access_control_post_id.present? ? @upload.access_control_post : nil
  end

  def insecure_context_checks
    {
      secure_media_disabled: "secure media is disabled",
      insecure_creation_for_modifiers: "one or more creation for_modifiers was satisfied",
      public_type: "upload is public type",
      custom_emoji: "upload is used for custom emoji",
      regular_emoji: "upload is used for regular emoji"
    }
  end

  def secure_context_checks
    {
      login_required: "login is required",
      access_control_post_has_secure_media: "access control post dictates security",
      secure_creation_for_modifiers: "one or more creation for_modifiers was satisfied",
      uploading_in_composer: "uploading via the composer",
      already_secure: "upload is already secure"
    }
  end

  # the access control check is important because that is the truest indicator
  # of whether an upload should be secure or not, and thus should be returned
  # immediately if there is an access control post
  def priority_check?(check)
    check == :access_control_post_has_secure_media && access_control_post
  end

  def perform_check(check)
    send("#{check}_check")
  end
end
