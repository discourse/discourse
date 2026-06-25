# frozen_string_literal: true

Fabricator(:access_control_list) do
  target { Fabricate(:category) }
  permission { "view" }
  owner { "core" }
  allowed_user_ids { [] }
  allowed_group_ids { [] }
end

Fabricator(:access_control_list_with_users, from: :access_control_list) do
  transient :users
  allowed_user_ids { |attrs| attrs[:users].map(&:id) }
end

Fabricator(:access_control_list_with_groups, from: :access_control_list) do
  transient :groups
  allowed_group_ids { |attrs| attrs[:groups].map(&:id) }
end

Fabricator(:access_control_list_with_users_and_groups, from: :access_control_list) do
  transient :users, :groups
  allowed_user_ids { |attrs| attrs[:users].map(&:id) }
  allowed_group_ids { |attrs| attrs[:groups].map(&:id) }
end
