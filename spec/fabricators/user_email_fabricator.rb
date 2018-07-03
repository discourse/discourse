Fabricator(:user_email) do
  email { sequence(:email) { |i| "bruce#{i}@wayne.com" } }
  primary true
end

Fabricator(:secondary_email, from: :user_email) do
  email { sequence(:email) { |i| "bwayne#{i}@wayne.com" } }
  primary false
end
