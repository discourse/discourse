# frozen_string_literal: true

class UserApiKey::DeviceAuth::Poll
  include Service::Base

  params do
    attribute :device_code, :string

    validates :device_code, presence: true
  end

  model :poll_response, :poll_device_request

  private

  def poll_device_request(params:)
    if !UserApiKey::DeviceAuth::DEVICE_CODE_REGEX.match?(params.device_code.to_s)
      return { status: "expired_token" }
    end

    grant = UserApiKey::DeviceAuth::GrantStore.load(params.device_code)
    return { status: "expired_token" } if grant.blank?

    if grant.pending?
      { status: "authorization_pending" }
    elsif grant.authorized?
      authorized_grant = UserApiKey::DeviceAuth::GrantStore.consume_authorized(params.device_code)
      if authorized_grant == UserApiKey::DeviceAuth::GrantStore::CONSUME_LOCKED
        { status: "authorization_pending" }
      elsif authorized_grant.present?
        { status: "authorized", payload: authorized_grant.payload }
      else
        { status: "expired_token" }
      end
    elsif grant.denied?
      { status: "access_denied" }
    else
      { status: "expired_token" }
    end
  end
end
