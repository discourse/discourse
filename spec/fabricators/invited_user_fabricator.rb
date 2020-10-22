# frozen_string_literal: true

Fabricator(:invited_user) do
  user
  invite
end
