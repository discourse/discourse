Fabricator(:user_email) do
  email { sequence(:email) { |i| "bruce#{i}@wayne.com" } }
  primary true
end
