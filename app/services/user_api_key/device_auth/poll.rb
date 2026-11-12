# frozen_string_literal: true

class UserApiKey::DeviceAuth::Poll
  include Service::Base

  params do
    attribute :device_code, :string

    validates :device_code, presence: true
  end

  options { attribute :request_id, :string }

  model :poll_response, :poll_device_request

  private

  def poll_device_request(params:, options:)
    device_code = params.device_code
    request_id = options.request_id

    if !UserApiKey::DeviceAuth::DEVICE_CODE_REGEX.match?(device_code.to_s)
      return(
        poll_response(
          UserApiKey::DeviceAuth::POLL_STATUS_EXPIRED_TOKEN,
          reason: "invalid_device_code",
          device_code: device_code,
          request_id: request_id,
        )
      )
    end

    grant = UserApiKey::DeviceAuth::GrantStore.load(device_code)
    if grant.blank?
      return(
        poll_response(
          UserApiKey::DeviceAuth::POLL_STATUS_EXPIRED_TOKEN,
          reason: "grant_missing",
          device_code: device_code,
          request_id: request_id,
        )
      )
    end

    if grant.pending?
      poll_response(
        UserApiKey::DeviceAuth::POLL_STATUS_AUTHORIZATION_PENDING,
        reason: "grant_pending",
        grant: grant,
        device_code: device_code,
        request_id: request_id,
      )
    elsif grant.authorized?
      authorized_grant =
        UserApiKey::DeviceAuth::GrantStore.consume_authorized(device_code, request_id: request_id)
      if authorized_grant == UserApiKey::DeviceAuth::GrantStore::CONSUME_LOCKED
        poll_response(
          UserApiKey::DeviceAuth::POLL_STATUS_AUTHORIZATION_PENDING,
          reason: "authorized_grant_locked",
          grant: grant,
          device_code: device_code,
          request_id: request_id,
        )
      elsif authorized_grant.present?
        poll_response(
          UserApiKey::DeviceAuth::POLL_STATUS_AUTHORIZED,
          reason: "authorized_grant_consumed",
          grant: authorized_grant,
          device_code: device_code,
          request_id: request_id,
          payload: authorized_grant.payload,
        )
      else
        poll_response(
          UserApiKey::DeviceAuth::POLL_STATUS_EXPIRED_TOKEN,
          reason: "authorized_grant_missing_after_lock",
          grant: grant,
          device_code: device_code,
          request_id: request_id,
        )
      end
    elsif grant.denied?
      poll_response(
        UserApiKey::DeviceAuth::POLL_STATUS_ACCESS_DENIED,
        reason: "grant_denied",
        grant: grant,
        device_code: device_code,
        request_id: request_id,
      )
    else
      poll_response(
        UserApiKey::DeviceAuth::POLL_STATUS_EXPIRED_TOKEN,
        reason: "unknown_grant_status",
        grant: grant,
        device_code: device_code,
        request_id: request_id,
      )
    end
  end

  def poll_response(status, device_code:, request_id:, reason:, grant: nil, payload: nil)
    UserApiKey::DeviceAuth.trace(
      "device_auth.poll.checked",
      request_id: request_id,
      reason: reason,
      status: status,
      grant_status: grant&.status,
      client_id: grant&.client_id,
      device_code: device_code,
    )

    response = { status: status }
    response[:payload] = payload if payload.present?
    response
  end
end
