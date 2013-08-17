Fabricator(:screened_email) do
  email { sequence(:email) { |n| "bad#{n}@spammers.org" } }
  action_type ScreenedEmail.actions[:block]
end
