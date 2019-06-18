# frozen_string_literal: true

Fabricator(:readonly_user_api_key, from: :user_api_key) do
  user
  scopes ['read']
  client_id { SecureRandom.hex }
  key { SecureRandom.hex }
  application_name 'some app'
end
