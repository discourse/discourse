# frozen_string_literal: true

class Auth::Result
  ATTRIBUTES = [
    :user,
    :name,
    :username,
    :email,
    :email_valid,
    :extra_data,
    :awaiting_activation,
    :awaiting_approval,
    :authenticated,
    :authenticator_name,
    :requires_invite,
    :not_allowed_from_ip_address,
    :admin_not_allowed_from_ip_address,
    :omit_username, # Used by plugins to prevent username edits
    :skip_email_validation,
    :destination_url,
    :omniauth_disallow_totp,
    :failed,
    :failed_reason,
    :failed_code
  ]

  attr_accessor *ATTRIBUTES

  # These are stored in the session during
  # account creation. The user cannot read or modify them
  SESSION_ATTRIBUTES = [
    :email,
    :username,
    :email_valid,
    :omit_username,
    :name,
    :authenticator_name,
    :extra_data,
    :skip_email_validation
  ]

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
    if !val.in? [true, false, nil]
      raise ArgumentError, "email_valid should be boolean or nil"
    end
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
    data = data.symbolize_keys
    SESSION_ATTRIBUTES.each { |att| result.public_send("#{att}=", data[att]) }
    result.user = user
    result
  end

  def apply_user_attributes!
    change_made = false
    if SiteSetting.auth_overrides_username? && username.present? && username != user.username
      user.username = UserNameSuggester.suggest(username_suggester_attributes, user.username)
      change_made = true
    end

    if SiteSetting.auth_overrides_email && email_valid && email.present? && user.email != Email.downcase(email)
      user.email = email
      change_made = true
    end

    if SiteSetting.auth_overrides_name && name.present? && user.name != name
      user.name = name
      change_made = true
    end

    change_made
  end

  def can_edit_name
    !SiteSetting.auth_overrides_name
  end

  def can_edit_username
    !(SiteSetting.auth_overrides_username || omit_username)
  end

  def to_client_hash
    if requires_invite
      return { requires_invite: true }
    end

    if user&.suspended?
      return {
        suspended: true,
        suspended_message: I18n.t(user.suspend_reason ? "login.suspended_with_reason" : "login.suspended",
                                   date: I18n.l(user.suspended_till, format: :date_only), reason: user.suspend_reason)
      }
    end

    if omniauth_disallow_totp
      return {
        omniauth_disallow_totp: !!omniauth_disallow_totp,
        email: email
      }
    end

    if user
      result = {
        authenticated: !!authenticated,
        awaiting_activation: !!awaiting_activation,
        awaiting_approval: !!awaiting_approval,
        not_allowed_from_ip_address: !!not_allowed_from_ip_address,
        admin_not_allowed_from_ip_address: !!admin_not_allowed_from_ip_address
      }

      result[:destination_url] = destination_url if authenticated && destination_url.present?

      return result
    end

    suggested_username = UserNameSuggester.suggest(username_suggester_attributes)
    if email_valid && email.present?
      if username.present? && User.username_available?(username, email)
        suggested_username = username
      elsif staged_user = User.where(staged: true).find_by_email(email)
        suggested_username = staged_user.username
      end
    end

    result = {
      email: email,
      username: suggested_username,
      auth_provider: authenticator_name,
      email_valid: !!email_valid,
      can_edit_username: can_edit_username,
      can_edit_name: can_edit_name
    }

    result[:destination_url] = destination_url if destination_url.present?

    if SiteSetting.enable_names?
      result[:name] = name.presence
      result[:name] ||= User.suggest_name(username || email) if can_edit_name
    end

    result
  end

  private

  def username_suggester_attributes
    username || name || email
  end
end
