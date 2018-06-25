Fabricator(:user_second_factor_totp, from: :user_second_factor) do
  user
  data 'rcyryaqage3jexfj'
  enabled true
  method UserSecondFactor.methods[:totp]
end

Fabricator(:user_second_factor_backup, from: :user_second_factor) do
  user
  # data "['65108096d23a70918e51332496b37425fe2be87fce29b97a19474f318e226314', 'c8177f837c3917d17eb015f4059101dfac399a3e0cc33ea5c56600bae58e2e0d', 'f954ddffa6830e3cd4fbdb66b6615ff150c8812f7e293ba5cb216f7852d5c254']"
  enabled true
  method UserSecondFactor.methods[:backup_codes]
end
