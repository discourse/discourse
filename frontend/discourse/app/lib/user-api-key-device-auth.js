export const USER_API_KEY_AUTHORIZATION_STATES = {
  READY: "ready",
  NO_TRUST_LEVEL: "no_trust_level",
  GENERIC_ERROR: "generic_error",
};

// Keep these values in sync with `UserApiKey::DeviceAuth` state/status constants.
export const USER_API_KEY_DEVICE_ACTIVATION_STATES = {
  ENTER_CODE: "enter_code",
  AUTHORIZE: "authorize",
  COMPLETE: "complete",
};

// CLI poll statuses returned by `/user-api-key/device/poll.json`.
export const USER_API_KEY_DEVICE_POLL_STATUSES = {
  AUTHORIZATION_PENDING: "authorization_pending",
  AUTHORIZED: "authorized",
  ACCESS_DENIED: "access_denied",
  EXPIRED_TOKEN: "expired_token",
};
