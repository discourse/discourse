# frozen_string_literal: true

class UserApiKey::DeviceAuth
  # Device auth flow:
  #
  # 1. A client POSTs to `/user-api-key/device.json`.
  #    `CreateRequest` validates the request, stores a short-lived pending grant in Redis, and
  #    returns a device code, a user-facing code, and an 8-character request token.
  # 2. The user visits `/user-api-key/activate` manually, or opens the request-token URL.
  #    `UserActivation` loads the pending grant and validates user-facing codes/tokens.
  # 3. The user confirms the code. Manual-code approvals bind the pending grant to the
  #    approving user and receive a browser-session approval token. Request-token approvals
  #    bind the pending grant to the approving user after a matching code is submitted.
  # 4. `Authorize` creates the User API key, encrypts the response payload, stores it briefly,
  #    and removes the user-code/request-token indexes.
  # 5. The client polls until `Poll` returns pending, denied, expired, or the encrypted payload.
  AUTH_API_VERSION = UserApiKeysController::AUTH_API_VERSION
  ALLOWED_PADDING_MODES = UserApiKeysController::ALLOWED_PADDING_MODES
  DEVICE_AUTH_TTL = 10.minutes
  DEVICE_AUTH_INTERVAL = 5
  DEVICE_AUTHORIZED_PAYLOAD_TTL = 1.minute
  DEVICE_KEY_PLACEHOLDER = "x" * 32
  DEVICE_CODE_REDIS_PREFIX = "user_api_key:device:".freeze
  DEVICE_USER_CODE_REDIS_PREFIX = "user_api_key:device:code:".freeze
  DEVICE_REQUEST_REDIS_PREFIX = "user_api_key:device:request:".freeze
  DEVICE_AUTHORIZATION_LOCK_REDIS_PREFIX = "user_api_key:device:lock:".freeze
  USER_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".freeze
  DEVICE_CODE_REGEX = /\A\h{64}\z/
  DEVICE_REQUEST_TOKEN_REGEX = /\A[-_A-Za-z0-9]{8}\z/
  DISALLOWED_DEVICE_SCOPES = Set.new(%w[one_time_password])
  MAX_DEVICE_CLIENT_ID_LENGTH = 200
  MAX_DEVICE_APPLICATION_NAME_LENGTH = 200
  MAX_DEVICE_NONCE_LENGTH = 256
  MAX_DEVICE_PUBLIC_KEY_LENGTH = 4096
  MAX_DEVICE_PUSH_URL_LENGTH = 2000
  MAX_DEVICE_SCOPES_LENGTH = 500
  MAX_DEVICE_SCOPES_COUNT = 20
  MAX_DEVICE_GRANT_BYTES = 10_000
  MIN_DEVICE_RSA_BITS = 2048
  MAX_DEVICE_RSA_BITS = 8192
  DEVICE_AUTHORIZATION_LOCK_TTL = 30.seconds

  def self.clear!
    UserApiKey::DeviceAuth::GrantStore.clear!
    UserApiKey::DeviceAuth::CodeRegistry.clear!
  end
end
