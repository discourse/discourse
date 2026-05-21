# frozen_string_literal: true

class UserApiKey::DeviceAuth::GrantPresenter
  attr_reader :grant

  def initialize(grant)
    @grant = grant
  end

  def device_code
    grant["device_code"]
  end

  def user_code
    grant["user_code"]
  end

  def application_name
    grant["application_name"]
  end

  def client_id
    grant["client_id"]
  end

  def localized_scopes
    scopes.map { |scope| I18n.t("user_api_key.scopes.#{scope}") }
  end

  def scopes
    Array(grant["scopes"])
  end

  def scopes_csv
    scopes.join(",")
  end

  def write_scope?
    scopes.include?("write")
  end

  def push_url
    grant["push_url"]
  end

  def padding
    grant["padding"]
  end

  def expires_in_seconds
    grant["expires_in_seconds"]
  end

  def expires_at
    UserApiKey::DeviceAuth::Expiry.requested_expires_at(expires_in_seconds)
  end

  def unregistered_client?
    !!grant["unregistered_client"]
  end
end
