# frozen_string_literal: true

Fabricator(:user_security_key) do
  user
  # Note: these values are valid and decode to a credential ID and COSE public key
  # HOWEVER they are largely useless unless you have the device that created
  # them. It is nice to have an approximation though.
  credential_id { 'mJAJ4CznTO0SuLkJbYwpgK75ao4KMNIPlU5KWM92nq39kRbXzI9mSv6GxTcsMYoiPgaouNw7b7zBiS4vsQaO6A==' }
  public_key { 'pQECAyYgASFYIMNgw4GCpwBUlR2SznJ1yY7B9yFvsuxhfo+C9kcA4IitIlggRdofrCezymy2B/YarX+gfB6gZKg648/cHIMjf6wWmmU=' }
  enabled true
  factor_type { UserSecurityKey.factor_types[:second_factor] }
  name { sequence(:name) { |i| "Security Key #{i + 1}" } }
end

##
# Useful for specs that just need a user security key model but not
# any of the related usefulness as a webauthn credential, because the
# credential_id has a UNIQUE index
Fabricator(:user_security_key_with_random_credential, from: :user_security_key) do
  credential_id { SecureRandom.base64(40) }
  public_key { SecureRandom.base64(40) }
end
