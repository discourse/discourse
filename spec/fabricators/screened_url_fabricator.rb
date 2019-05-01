# frozen_string_literal: true

Fabricator(:screened_url) do
  url         { sequence(:url)    { |n| "spammers#{n}.org/buy/stuff" } }
  domain      { sequence(:domain) { |n| "spammers#{n}.org" } }
  action_type ScreenedEmail.actions[:do_nothing]
end
