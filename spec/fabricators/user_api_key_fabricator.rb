Fabricator(:readonly_user_api_key, from: :user_api_key) do
  user
  scopes %w[read]
  client_id { SecureRandom.hex }
  key { SecureRandom.hex }
  application_name 'some app'
end
