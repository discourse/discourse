# frozen_string_literal: true

RSpec.describe "tasks/users" do
  describe "users:disable_2fa" do
    let(:user) { Fabricate(:user) }

    it "should remove all 2fa methods for user with given username" do
      Fabricate(:user_second_factor_totp, user: user, name: "TOTP", enabled: true)
      Fabricate(:user_second_factor_totp, user: user, name: "TOTP2", enabled: true)
      Fabricate(
        :user_security_key_with_random_credential,
        user: user,
        name: "YubiKey",
        enabled: true,
      )
      Fabricate(:passkey_with_random_credential, user: user) # This should not be removed

      backup_codes = user.generate_backup_codes

      expect(backup_codes.length).to be 10
      expect(user.user_second_factors.backup_codes).to be_present
      expect(user.user_second_factors.totps.count).to eq(2)
      expect(user.second_factor_security_keys.count).to eq(1)

      stdout = capture_stdout { invoke_rake_task("users:disable_2fa", user.username) }
      user.reload

      expect(stdout.chomp).to eq("2FA disabled for #{user.username}")
      expect(user.user_second_factors.totps.count).to eq(0)
      expect(user.second_factor_security_keys.count).to eq(0)
      expect(user.user_second_factors.backup_codes.count).to eq(0)
      expect(user.passkey_credential_ids.count).to eq(1)
    end
  end
end
