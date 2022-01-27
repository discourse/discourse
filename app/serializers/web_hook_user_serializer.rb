# frozen_string_literal: true

class WebHookUserSerializer < UserSerializer
  attributes :external_id

  # remove staff attributes
  def staff_attributes(*attrs)
  end

  %i{
    unconfirmed_emails
    can_edit
    can_edit_username
    can_edit_email
    can_edit_name
    can_send_private_messages
    can_send_private_message_to_user
    can_ignore_user
    can_mute_user
    ignored
    uploaded_avatar_id
    has_title_badges
    bio_cooked
    custom_fields
    can_be_deleted
    can_delete_all_posts
    system_avatar_upload_id
    gravatar_avatar_upload_id
    custom_avatar_upload_id
    can_change_bio
    can_change_location
    can_change_website
    can_change_tracking_preferences
    user_api_keys
    group_users
    user_auth_tokens
    user_auth_token_logs
    use_logo_small_as_avatar
    pending_posts_count
  }.each do |attr|
    define_method("include_#{attr}?") do
      false
    end
  end

  def include_email?
    scope.is_admin?
  end

  alias_method :include_secondary_emails?, :include_email?

  def include_external_id?
    scope.is_admin? && object.single_sign_on_record
  end

  def external_id
    object.single_sign_on_record.external_id
  end

end
