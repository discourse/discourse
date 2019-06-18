# frozen_string_literal: true

Fabricator(:user_second_factor_totp, from: :user_second_factor) do
  user
  data 'rcyryaqage3jexfj'
  enabled true
  method UserSecondFactor.methods[:totp]
end

Fabricator(:user_second_factor_backup, from: :user_second_factor) do
  user
  # backup code: iAmValidBackupCode
  data '{"salt":"e84ab3842f173967ca85ca6f5639b7ab","code_hash":"6abfe07527e2f7db45980cf67b9b4bfc7fbeea2685b07dcc3bf49f21349707f3"}'
  enabled true
  method UserSecondFactor.methods[:backup_codes]
end
