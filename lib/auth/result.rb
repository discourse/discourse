# frozen_string_literal: true

class Auth::Result
  ATTRIBUTES = %i[
    user
    name
    username
    email
    email_valid
    extra_data
    awaiting_activation
    awaiting_approval
    authenticated
    authenticator_name
    requires_invite
    not_allowed_from_ip_address
    admin_not_allowed_from_ip_address
    skip_email_validation
    destination_url
    omniauth_disallow_totp
    failed
    failed_reason
    failed_code
    associated_groups
    overrides_email
    overrides_username
    overrides_name
  ].freeze

  attr_accessor *ATTRIBUTES

  # These are stored in the session during
  # account creation. The user cannot read or modify them
  SESSION_ATTRIBUTES = %i[
    email
    username
    email_valid
    name
    authenticator_name
    extra_data
    skip_email_validation
    associated_groups
    overrides_email
    overrides_username
    overrides_name
  ].freeze

  def [](key)
    key = key.to_sym
    public_send(key) if ATTRIBUTES.include?(key)
  end

  def initialize
    @failed = false
  end

  def email
    @email&.downcase
  end

  def email_valid=(val)
    raise ArgumentError, "email_valid should be boolean or nil" if !val.in? [true, false, nil]
    @email_valid = !!val
  end

  def failed?
    !!@failed
  end

  def session_data
    SESSION_ATTRIBUTES.map { |att| [att, public_send(att)] }.to_h
  end

  def self.from_session_data(data, user:)
    result = new
    data = data.with_indifferent_access
    SESSION_ATTRIBUTES.each { |att| result.public_send("#{att}=", data[att]) }
    result.user = user
    result
  end

  def apply_user_attributes!
    change_made = false
    if (SiteSetting.auth_overrides_username? || overrides_username) &&
         (resolved_username = resolve_username).present?
      change_made = UsernameChanger.override(user, resolved_username)
    end

    if (
         SiteSetting.auth_overrides_email || overrides_email || user&.email&.ends_with?(".invalid")
       ) && email_valid && email.present? && user.email != Email.downcase(email)
      user.email = email
      change_made = true
    end

    if (SiteSetting.auth_overrides_name || overrides_name) && name.present? && user.name != name
      user.name = name
      change_made = true
    end

    change_made
  end

  def apply_associated_attributes!
    if authenticator&.provides_groups? && !associated_groups.nil?
      associated_group_ids = []

      associated_groups.uniq.each do |associated_group|
        begin
          associated_group =
            AssociatedGroup.find_or_create_by(
              name: associated_group[:name],
              provider_id: associated_group[:id],
              provider_name: extra_data[:provider],
            )
        rescue ActiveRecord::RecordNotUnique
          retry
        end

        associated_group_ids.push(associated_group.id)
      end

      user.update(associated_group_ids: associated_group_ids)
      AssociatedGroup.where(id: associated_group_ids).update_all("last_used = CURRENT_TIMESTAMP")
    end
  end

  def can_edit_name
    !(SiteSetting.auth_overrides_name || overrides_name)
  end

  def can_edit_username
    !(SiteSetting.auth_overrides_username || overrides_username)
  end

  def to_client_hash
    return { requires_invite: true } if requires_invite

    return { suspended: true, suspended_message: user.suspended_message } if user&.suspended?

    if omniauth_disallow_totp
      return { omniauth_disallow_totp: !!omniauth_disallow_totp, email: email }
    end

    if user
      result = {
        authenticated: !!authenticated,
        awaiting_activation: !!awaiting_activation,
        awaiting_approval: !!awaiting_approval,
        not_allowed_from_ip_address: !!not_allowed_from_ip_address,
        admin_not_allowed_from_ip_address: !!admin_not_allowed_from_ip_address,
      }

      result[:destination_url] = destination_url if authenticated && destination_url.present?

      return result
    end

    result = {
      email: email,
      username: resolve_username,
      auth_provider: authenticator_name,
      email_valid: !!email_valid,
      can_edit_username: can_edit_username,
      can_edit_name: can_edit_name,
    }

    result[:destination_url] = destination_url if destination_url.present?

    if SiteSetting.enable_names?
      result[:name] = name.presence
      result[:name] ||= User.suggest_name(username || email) if can_edit_name
    end

    result
  end

  private

  def staged_user
    return @staged_user if defined?(@staged_user)
    @staged_user = User.where(staged: true).find_by_email(email) if email.present? && email_valid
  end

  def username_suggester_attributes
    attributes = [username]
    attributes << name if SiteSetting.use_name_for_username_suggestions
    attributes << email if SiteSetting.use_email_for_username_and_name_suggestions
    attributes
  end

  def authenticator
    @authenticator ||= Discourse.enabled_authenticators.find { |a| a.name == authenticator_name }
  end

  def resolve_username
    if staged_user
      if !username.present? || UserNameSuggester.fix_username(username) == staged_user.username
        return staged_user.username
      end
    end

    UserNameSuggester.suggest(*username_suggester_attributes, current_username: user&.username)
  end
end
