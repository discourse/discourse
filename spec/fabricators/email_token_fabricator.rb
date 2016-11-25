Fabricator(:email_token) do
  user
  email { |attrs| attrs[:user].email }
end
