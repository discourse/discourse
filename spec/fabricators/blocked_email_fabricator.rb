Fabricator(:blocked_email) do
  email { sequence(:email) { |n| "bad#{n}@spammers.org" } }
  action_type BlockedEmail.actions[:block]
end
