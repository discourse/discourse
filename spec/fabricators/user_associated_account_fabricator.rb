# frozen_string_literal: true

Fabricator(:user_associated_account) do
  provider_name "meecrosof"
  provider_uid { sequence(:key) { |i| "#{i + 1}" } }
  user
  info { |attrs| { name: attrs[:user].username, email: attrs[:user].email } }
end
