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
      UserApiKey::DeviceAuth::GrantStore.delete(params.device_code)
      { status: "authorized", payload: grant.payload }
    elsif grant.denied?
      { status: "access_denied" }
    else
      { status: "expired_token" }
    end
  end
end
