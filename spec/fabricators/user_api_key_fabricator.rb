# frozen_string_literal: true

Fabricator(:user_api_key_scope)

Fabricator(:readonly_user_api_key, from: :user_api_key) do
  user
  scopes { [Fabricate.build(:user_api_key_scope, name: 'read')] }
  client_id { SecureRandom.hex }
  application_name 'some app'
end

Fabricator(:bookmarks_calendar_user_api_key, from: :user_api_key) do
  user
  scopes { [Fabricate.build(:user_api_key_scope, name: 'bookmarks_calendar')] }
  client_id { SecureRandom.hex }
  application_name 'some app'
end
