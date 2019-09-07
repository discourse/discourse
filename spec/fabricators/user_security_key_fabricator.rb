# frozen_string_literal: true

Fabricator(:user_security_key) do
  user
  credential_id { SecureRandom.hex(10) }
  public_key { SecureRandom.hex(10) }
  enabled true
  name { sequence(:name) { |i| "Security Key #{i + 1}" } }
end
