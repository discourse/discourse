# frozen_string_literal: true

Fabricator(:user_status) do
  user
  set_at { Time.zone.now }

  description { "off to dentists" }
  emoji { "tooth" }
end
