# frozen_string_literal: true

class UserApiKey::DeviceAuth::Deny
  include Service::Base

  params do
    attribute :device_code, :string

    validates :device_code, presence: true
  end

  options { attribute :request_id, :string }

  try Discourse::InvalidParameters, Discourse::InvalidAccess do
    step :deny_grant
  end

  private

  def deny_grant(params:, options:)
    failure_reason = nil
    grant_status = nil
    client_id = nil

    UserApiKey::DeviceAuth::GrantStore.with_lock!(
      params.device_code,
      operation: "device_auth.deny",
      request_id: options.request_id,
    ) do
      grant = UserApiKey::DeviceAuth::GrantStore.load(params.device_code)
      grant_status = grant&.status
      client_id = grant&.client_id

      failure_reason =
        if grant.blank?
          "grant_missing"
        elsif grant.pending?
          grant.deny!
          UserApiKey::DeviceAuth::GrantStore.save!(
            grant,
            ttl: UserApiKey::DeviceAuth::GrantStore.ttl_for_update(params.device_code),
          )
          UserApiKey::DeviceAuth::CodeRegistry.delete_indexes_for(grant)
          grant_status = grant.status
          nil
        elsif grant.denied?
          nil
        else
          "grant_not_pending"
        end
    end

    if failure_reason.present?
      UserApiKey::DeviceAuth.trace(
        "device_auth.deny.failed",
        request_id: options.request_id,
        reason: failure_reason,
        status: grant_status,
        client_id: client_id,
        device_code: params.device_code,
      )
      fail!(failure_reason)
    end

    UserApiKey::DeviceAuth.trace(
      "device_auth.deny.succeeded",
      request_id: options.request_id,
      status: grant_status,
      client_id: client_id,
      device_code: params.device_code,
    )
  rescue Discourse::InvalidParameters, Discourse::InvalidAccess => exception
    UserApiKey::DeviceAuth.trace(
      "device_auth.deny.failed",
      request_id: options.request_id,
      reason: exception.class.name,
      exception: exception,
      device_code: params.device_code,
    )
    raise
  end
end
