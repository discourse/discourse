# frozen_string_literal: true

module UserApiKeyDeviceAuthSpecHelpers
  def clear_user_api_key_device_auth_redis!
    UserApiKey::DeviceAuth.clear!
  end

  def create_user_api_key_device_auth_request!(params:, client: nil)
    UserApiKey::DeviceAuth::CreateRequest.call(params: params)[:device_request]
  end
end

RSpec.configure { |config| config.include UserApiKeyDeviceAuthSpecHelpers }
