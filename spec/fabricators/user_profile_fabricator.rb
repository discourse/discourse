Fabricator(:user_profile) do
  bio_raw "I'm batman!"
end

Fabricator(:user_profile_long, from: :user_profile) do
  bio_raw ("trout" * 1000)
  user
end
