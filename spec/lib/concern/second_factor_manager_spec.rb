# frozen_string_literal: true

RSpec.describe SecondFactorManager do
  fab!(:user)
  fab!(:user_second_factor_totp) { Fabricate(:user_second_factor_totp, user: user) }
  fab!(:user_security_key) do
    Fabricate(
      :user_security_key,
      user: user,
      public_key: valid_security_key_data[:public_key],
      credential_id: valid_security_key_data[:credential_id],
    )
  end
  fab!(:another_user, :user)

  fab!(:user_second_factor_backup)
  let(:user_backup) { user_second_factor_backup.user }

  describe "#totp" do
    it "returns the right data" do
      totp = nil

      expect do totp = another_user.create_totp(enabled: true) end.to change {
        UserSecondFactor.count
      }.by(1)

      expect(totp.totp_object.issuer).to eq(SiteSetting.title)
      expect(totp.totp_object.secret).to eq(
        another_user.reload.user_second_factors.totps.first.data,
      )
    end
  end

  describe "#create_totp" do
    it "creates the right record" do
      second_factor = another_user.create_totp(enabled: true)

      expect(second_factor.method).to eq(UserSecondFactor.methods[:totp])
      expect(second_factor.data).to be_present
      expect(second_factor.enabled).to eq(true)
    end
  end

  describe "#totp_provisioning_uri" do
    it "returns the right uri" do
      expect(user.user_second_factors.totps.first.totp_provisioning_uri).to eq(
        "otpauth://totp/#{SiteSetting.title}:#{ERB::Util.url_encode(user.email)}?secret=#{user_second_factor_totp.data}&issuer=#{SiteSetting.title}",
      )
    end

    it "handles a colon in the site title" do
      SiteSetting.title = "Spaceballs: The Discourse"
      expect(user.user_second_factors.totps.first.totp_provisioning_uri).to eq(
        "otpauth://totp/Spaceballs%20The%20Discourse:#{ERB::Util.url_encode(user.email)}?secret=#{user_second_factor_totp.data}&issuer=Spaceballs%20The%20Discourse",
      )
    end

    it "handles a two words before a colon in the title" do
      SiteSetting.title = "Our Spaceballs: The Discourse"
      expect(user.user_second_factors.totps.first.totp_provisioning_uri).to eq(
        "otpauth://totp/Our%20Spaceballs%20The%20Discourse:#{ERB::Util.url_encode(user.email)}?secret=#{user_second_factor_totp.data}&issuer=Our%20Spaceballs%20The%20Discourse",
      )
    end
  end

  describe "#authenticate_totp" do
    it "is able to authenticate a token" do
      freeze_time do
        expect(user.user_second_factors.totps.first.last_used).to eq(nil)

        token = user.user_second_factors.totps.first.totp_object.now

        expect(user.authenticate_totp(token)).to eq(true)
        expect(user.user_second_factors.totps.first.last_used).to eq_time(Time.zone.now)
        expect(user.authenticate_totp(token)).to eq(false)
      end
    end

    describe "when token is blank" do
      it "is false" do
        expect(user.authenticate_totp(nil)).to eq(false)
        expect(user.user_second_factors.totps.first.last_used).to eq(nil)
      end
    end

    describe "when token is invalid" do
      it "is false" do
        expect(user.authenticate_totp("111111")).to eq(false)
        expect(user.user_second_factors.totps.first.last_used).to eq(nil)
      end
    end
  end

  describe "#totp_enabled?" do
    describe "when user does not have a second factor record" do
      it "returns false" do
        expect(another_user.totp_enabled?).to eq(false)
      end
    end

    describe "when user's second factor record is disabled" do
      it "returns false" do
        disable_totp
        expect(user.totp_enabled?).to eq(false)
      end
    end

    describe "when user's second factor record is enabled" do
      it "returns true" do
        expect(user.totp_enabled?).to eq(true)
      end
    end

    describe "when SSO is enabled" do
      it "returns false" do
        SiteSetting.discourse_connect_url = "http://someurl.com"
        SiteSetting.discourse_connect_secret = "x" * 10
        SiteSetting.enable_discourse_connect = true

        expect(user.totp_enabled?).to eq(false)
      end
    end

    describe "when local login is disabled" do
      it "returns false" do
        SiteSetting.enable_local_logins = false

        expect(user.totp_enabled?).to eq(false)
      end
    end
  end

  describe "#has_multiple_second_factor_methods?" do
    context "when security keys and totp are enabled" do
      it "returns true" do
        expect(user.has_multiple_second_factor_methods?).to eq(true)
      end
    end

    context "if the totp gets disabled" do
      it "returns false" do
        disable_totp
        expect(user.has_multiple_second_factor_methods?).to eq(false)
      end
    end

    context "if the security key gets disabled" do
      it "returns false" do
        disable_security_key
        expect(user.has_multiple_second_factor_methods?).to eq(false)
      end
    end
  end

  describe "#only_security_keys_enabled?" do
    it "returns true if totp disabled and security key enabled" do
      disable_totp
      expect(user.only_security_keys_enabled?).to eq(true)
    end
  end

  describe "#only_totp_or_backup_codes_enabled?" do
    it "returns true if totp enabled and security key disabled" do
      disable_security_key
      expect(user.only_totp_or_backup_codes_enabled?).to eq(true)
    end
  end

  describe "#passkeys_available_as_second_factor?" do
    before do
      SiteSetting.allow_passkeys_for_2fa = true
      Fabricate(:passkey_with_random_credential, user: user)
    end

    it "is true when both setting flags are on" do
      expect(user.passkeys_available_as_second_factor?).to eq(true)
    end

    it "is false when the global enable_passkeys kill switch is off" do
      SiteSetting.enable_passkeys = false
      expect(user.passkeys_available_as_second_factor?).to eq(false)
    end

    it "is false when allow_passkeys_for_2fa is off" do
      SiteSetting.allow_passkeys_for_2fa = false
      expect(user.passkeys_available_as_second_factor?).to eq(false)
    end

    it "is false when the user only has disabled passkeys" do
      user
        .security_keys
        .where(factor_type: UserSecurityKey.factor_types[:first_factor])
        .update_all(enabled: false)
      expect(user.passkeys_available_as_second_factor?).to eq(false)
    end

    it "is aliased as passkeys_for_2fa_enabled? for compatibility" do
      expect(user.passkeys_for_2fa_enabled?).to eq(true)
    end
  end

  describe "backup codes" do
    describe "#generate_backup_codes" do
      it "generates and store 10 backup codes" do
        backup_codes = user.generate_backup_codes

        expect(backup_codes.length).to be 10
        expect(user_backup.user_second_factors.backup_codes).to be_present
        expect(user_backup.user_second_factors.backup_codes.pluck(:method).uniq[0]).to eq(
          UserSecondFactor.methods[:backup_codes],
        )
        expect(user_backup.user_second_factors.backup_codes.pluck(:enabled).uniq[0]).to eq(true)
      end
    end

    describe "#create_backup_codes" do
      it "creates 10 backup code records" do
        raw_codes = Array.new(10) { SecureRandom.hex(8) }
        backup_codes = another_user.create_backup_codes(raw_codes)

        expect(another_user.user_second_factors.backup_codes.length).to be 10
      end
    end

    describe "#authenticate_backup_code" do
      it "is able to authenticate a backup code" do
        backup_code = "iAmValidBackupCode"

        expect(user_backup.authenticate_backup_code(backup_code)).to eq(true)
        expect(user_backup.authenticate_backup_code(backup_code)).to eq(false)
      end

      describe "when code is blank" do
        it "is false" do
          expect(user_backup.authenticate_backup_code(nil)).to eq(false)
        end
      end

      describe "when code is invalid" do
        it "is false" do
          expect(user_backup.authenticate_backup_code("notValidBackupCode")).to eq(false)
        end
      end
    end

    describe "#backup_codes_enabled?" do
      describe "when user does not have a second factor backup enabled" do
        it "returns false" do
          expect(another_user.backup_codes_enabled?).to eq(false)
        end
      end

      describe "when user's second factor backup codes have been used" do
        it "returns false" do
          user_backup.user_second_factors.backup_codes.update_all(enabled: false)
          expect(user_backup.backup_codes_enabled?).to eq(false)
        end
      end

      describe "when user's second factor code is available" do
        it "returns true" do
          expect(user_backup.backup_codes_enabled?).to eq(true)
        end
      end

      describe "when SSO is enabled" do
        it "returns false" do
          SiteSetting.discourse_connect_url = "http://someurl.com"
          SiteSetting.discourse_connect_secret = "x" * 10
          SiteSetting.enable_discourse_connect = true

          expect(user_backup.backup_codes_enabled?).to eq(false)
        end
      end

      describe "when local login is disabled" do
        it "returns false" do
          SiteSetting.enable_local_logins = false

          expect(user_backup.backup_codes_enabled?).to eq(false)
        end
      end
    end
  end

  def disable_totp
    user.user_second_factors.totps.first.update!(enabled: false)
  end

  def disable_security_key
    user.security_keys.first.destroy!
  end
end
