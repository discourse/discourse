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
# complex queries and joins to perform.
#
# These queries will be performed only if the @creating option is false. So if
# an upload is included in a post, and it's an upload from a different source
# (e.g. a category logo, site setting upload) then we will determine secure
# state _based on the first place the upload was referenced_.
#
# NOTE: When updating this to add more cases where uploads will be marked
# secure, consider uploads:secure_upload_analyse_and_update as well, which
# does not use this class directly but uses an SQL version of its rules for
# efficient updating of many uploads in bulk.
class UploadSecurity
  @@custom_public_types = []

  PUBLIC_TYPES = %w[
    avatar
    custom_emoji
    profile_background
    card_background
    category_logo
    category_logo_dark
    category_background
    group_flair
    badge_image
  ].freeze

  PUBLIC_UPLOAD_REFERENCE_TYPES = %w[
    Badge
    Category
    CustomEmoji
    Group
    SiteSetting
    ThemeField
    User
    UserAvatar
    UserProfile
  ].freeze

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
    insecure_context_checks.each { |check, reason| return false, reason if perform_check(check) }
    secure_context_checks.each do |check, reason|
      return perform_check(check), reason if priority_check?(check)
      return true, reason if perform_check(check)
    end

    [false, "no checks satisfied"]
  end

  private

  def access_control_post
    @access_control_post ||=
      @upload.access_control_post_id.present? ? @upload.access_control_post : nil
  end

  def insecure_context_checks
    {
      secure_uploads_disabled: "secure uploads is disabled",
      insecure_creation_for_modifiers: "one or more creation for_modifiers was satisfied",
      public_type: "upload is public type",
      regular_emoji: "upload is used for regular emoji",
      publicly_referenced_first: "upload was publicly referenced when it was first created",
    }
  end

  def secure_context_checks
    {
      login_required: "login is required",
      access_control_post_should_secure_uploads: "access control post dictates security",
      secure_creation_for_modifiers: "one or more creation for_modifiers was satisfied",
      uploading_in_composer: "uploading via the composer",
      already_secure: "upload is already secure",
    }
  end

  # The access control check is important because that is the truest indicator
  # of whether an upload should be secure or not, and thus should be returned
  # immediately if there is an access control post.
  def priority_check?(check)
    check == :access_control_post_should_secure_uploads && access_control_post
  end

  def perform_check(check)
    send("#{check}_check")
  end

  #### START PUBLIC CHECKS ####

  def secure_uploads_disabled_check
    !SiteSetting.secure_uploads?
  end

  def insecure_creation_for_modifiers_check
    return false if !@creating
    @upload.for_theme || @upload.for_site_setting || @upload.for_gravatar
  end

  def public_type_check
    PUBLIC_TYPES.include?(@upload_type) || @@custom_public_types.include?(@upload_type)
  end

  def publicly_referenced_first_check
    return false if @creating
    first_reference =
      @upload
        .upload_references
        .joins(<<~SQL)
          LEFT JOIN posts ON upload_references.target_type = 'Post' AND upload_references.target_id = posts.id
        SQL
        .where("posts.deleted_at IS NULL")
        .order("upload_references.created_at ASC, upload_references.id ASC")
        .first
    return false if first_reference.blank?
    PUBLIC_UPLOAD_REFERENCE_TYPES.include?(first_reference.target_type)
  end

  def regular_emoji_check
    return false if @upload.origin.blank?
    uri = URI.parse(@upload.origin)
    return true if Emoji.all.map(&:url).include?("#{uri.path}?#{uri.query}")
    uri.path.include?("images/emoji")
  end

  #### END PUBLIC CHECKS ####

  #--------------------------#

  #### START PRIVATE CHECKS ####

  def login_required_check
    SiteSetting.login_required? && !SiteSetting.secure_uploads_pm_only?
  end

  # Whether the upload should remain secure or not after posting depends on its context,
  # which is based on the post it is linked to via access_control_post_id.
  #
  # If that post should_secure_uploads? then the upload should also be secure.
  #
  # This may change to false if the upload was set to secure on upload e.g. in
  # a post composer then it turned out that the post itself was not in a secure context.
  #
  # A post is with secure uploads if it is a private message or in a read restricted
  # category. See `Post#should_secure_uploads?` for the full definition.
  def access_control_post_should_secure_uploads_check
    access_control_post&.should_secure_uploads?
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

  #### END PRIVATE CHECKS ####
end
