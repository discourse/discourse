Fabricator(:user_second_factor) do
  user
  data 'rcyryaqage3jexfj'
  enabled true
  method UserSecondFactor.methods[:totp]
end
