Fabricator(:email_change_request) do
  user
  old_email { sequence(:old_email) { |i| "bruce#{i}@wayne.com" } }
  new_email { sequence(:new_email) { |i| "super#{i}@man.com" } }
  change_state EmailChangeRequest.states[:authorizing_old]
end
