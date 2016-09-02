Fabricator(:readonly_user_api_key, from: :user_api_key) do
  user
  read true
  write false
  push false
  client_id { SecureRandom.hex }
  key { SecureRandom.hex }
  application_name 'some app'
end
