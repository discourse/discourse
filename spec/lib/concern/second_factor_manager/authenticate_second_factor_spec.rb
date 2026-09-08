# frozen_string_literal: true

RSpec.describe SecondFactorManager, "#authenticate_second_factor" do
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

  let(:params) { {} }
  let(:server_session) { ServerSession.new("some-prefix") }

  def disable_totp
    user.user_second_factors.totps.first.update!(enabled: false)
  end

  def disable_security_key
    user.security_keys.first.destroy!
  end

  context "when neither security keys nor totp/backup codes are enabled" do
    before { disable_security_key && disable_totp }

    it "returns OK, because it doesn't need to authenticate" do
      expect(user.authenticate_second_factor(params, server_session).ok).to eq(true)
    end

    it "keeps used_2fa_method nil because no authentication is done" do
      expect(user.authenticate_second_factor(params, server_session).used_2fa_method).to eq(nil)
    end

    context "when the user has a passkey and allow_passkeys_for_2fa is enabled" do
      # Login / email-login / password-reset flows call authenticate_second_factor
      # without a second_factor_method. They don't advertise passkeys, so a
      # passkey-only user must still pass through these flows; only the explicit
      # 2FA endpoint (which submits a method) should require passkey validation.
      before do
        SiteSetting.allow_passkeys_for_2fa = true
        Fabricate(:passkey_with_random_credential, user: user)
      end

      it "returns OK when no second_factor_method is submitted" do
        expect(user.authenticate_second_factor(params, server_session).ok).to eq(true)
      end

      it "validates the credential when the passkey method is submitted" do
        params_with_method = {
          second_factor_method: UserSecondFactor.methods[:passkey],
          second_factor_token: {
            credentialId: "missing",
          },
        }
        result = user.authenticate_second_factor(params_with_method, server_session)
        expect(result.ok).to eq(false)
      end

      it "rejects the security key method because passkeys are not security keys" do
        params_with_method = {
          second_factor_method: UserSecondFactor.methods[:security_key],
          second_factor_token: {
            credentialId: "missing",
          },
        }
        result = user.authenticate_second_factor(params_with_method, server_session)
        expect(result.ok).to eq(false)
        expect(result.error).to eq(I18n.t("login.not_enabled_second_factor_method"))
      end
    end
  end

  context "with the passkey ceremony" do
    before do
      Fabricate(
        :user_security_key,
        user: user,
        credential_id: valid_passkey_data[:credential_id],
        public_key: valid_passkey_data[:public_key],
        factor_type: UserSecurityKey.factor_types[:first_factor],
      )
      SiteSetting.allow_passkeys_for_2fa = true
      simulate_localhost_passkey_challenge
      DiscourseWebauthn.stage_challenge(user, server_session)
      DiscourseWebauthn.stubs(:origin).returns("http://localhost:3000")
    end

    context "when the passkey assertion is valid" do
      let(:params) do
        {
          second_factor_token: valid_passkey_auth_data,
          second_factor_method: UserSecondFactor.methods[:passkey],
        }
      end

      it "returns OK and sets used_2fa_method to passkey" do
        result = user.authenticate_second_factor(params, server_session)
        expect(result.ok).to eq(true)
        expect(result.used_2fa_method).to eq(UserSecondFactor.methods[:passkey])
      end
    end

    context "when a passkey assertion is posted as the security key method" do
      let(:params) do
        {
          second_factor_token: valid_passkey_auth_data,
          second_factor_method: UserSecondFactor.methods[:security_key],
        }
      end

      it "is rejected with an ownership error" do
        result = user.authenticate_second_factor(params, server_session)
        expect(result.ok).to eq(false)
        expect(result.error).to eq(I18n.t("webauthn.validation.ownership_error"))
      end
    end

    context "when a security key assertion is posted as the passkey method" do
      let(:params) do
        {
          second_factor_token: valid_security_key_auth_post_data,
          second_factor_method: UserSecondFactor.methods[:passkey],
        }
      end

      it "is rejected with an ownership error" do
        result = user.authenticate_second_factor(params, server_session)
        expect(result.ok).to eq(false)
        expect(result.error).to eq(I18n.t("webauthn.validation.ownership_error"))
      end
    end
  end

  context "when only security key is enabled" do
    before do
      disable_totp
      simulate_localhost_webauthn_challenge
      DiscourseWebauthn.stage_challenge(user, server_session)
      DiscourseWebauthn.stubs(:origin).returns("http://localhost:3000")
    end

    context "when security key params are valid" do
      let(:params) do
        {
          second_factor_token: valid_security_key_auth_post_data,
          second_factor_method: UserSecondFactor.methods[:security_key],
        }
      end

      it "returns OK" do
        expect(user.authenticate_second_factor(params, server_session).ok).to eq(true)
      end

      it "sets used_2fa_method to security keys" do
        expect(user.authenticate_second_factor(params, server_session).used_2fa_method).to eq(
          UserSecondFactor.methods[:security_key],
        )
      end
    end

    context "when security key params are invalid" do
      let(:params) do
        {
          second_factor_token: {
            signature: "bad",
            clientData: "bad",
            authenticatorData: "bad",
            credentialId: "bad",
          },
          second_factor_method: UserSecondFactor.methods[:security_key],
        }
      end

      it "returns not OK" do
        result = user.authenticate_second_factor(params, server_session)
        expect(result.ok).to eq(false)
        expect(result.error).to eq(I18n.t("webauthn.validation.not_found_error"))
        expect(result.used_2fa_method).to eq(nil)
      end
    end
  end

  context "when only totp is enabled" do
    before { disable_security_key }

    context "when totp is valid" do
      let(:params) do
        {
          second_factor_token: user.user_second_factors.totps.first.totp_object.now,
          second_factor_method: UserSecondFactor.methods[:totp],
        }
      end

      it "returns OK" do
        expect(user.authenticate_second_factor(params, server_session).ok).to eq(true)
      end

      it "sets used_2fa_method to totp" do
        expect(user.authenticate_second_factor(params, server_session).used_2fa_method).to eq(
          UserSecondFactor.methods[:totp],
        )
      end
    end

    context "when totp is invalid" do
      let(:params) do
        { second_factor_token: "blah", second_factor_method: UserSecondFactor.methods[:totp] }
      end

      it "returns not OK" do
        result = user.authenticate_second_factor(params, server_session)
        expect(result.ok).to eq(false)
        expect(result.error).to eq(I18n.t("login.invalid_second_factor_code"))
        expect(result.used_2fa_method).to eq(nil)
      end
    end
  end

  context "when both security keys and totp are enabled" do
    let(:invalid_method) { 99 }
    let(:method) { invalid_method }

    before do
      simulate_localhost_webauthn_challenge
      DiscourseWebauthn.stage_challenge(user, server_session)
      DiscourseWebauthn.stubs(:origin).returns("http://localhost:3000")
    end

    context "when method selected is invalid" do
      it "returns an error" do
        result = user.authenticate_second_factor(params, server_session)
        expect(result.ok).to eq(false)
        expect(result.error).to eq(I18n.t("login.invalid_second_factor_method"))
        expect(result.used_2fa_method).to eq(nil)
      end
    end

    context "when method selected is TOTP" do
      let(:method) { UserSecondFactor.methods[:totp] }
      let(:token) { user.user_second_factors.totps.first.totp_object.now }

      context "when totp params are provided" do
        let(:params) { { second_factor_token: token, second_factor_method: method } }

        it "validates totp OK" do
          expect(user.authenticate_second_factor(params, server_session).ok).to eq(true)
        end

        it "sets used_2fa_method to totp" do
          expect(user.authenticate_second_factor(params, server_session).used_2fa_method).to eq(
            UserSecondFactor.methods[:totp],
          )
        end

        it "returns an error when the user does not have TOTP enabled" do
          params
          user.totps.destroy_all
          params[:second_factor_token] = "test"
          result = user.authenticate_second_factor(params, server_session)
          expect(result.ok).to eq(false)
          expect(result.error).to eq(I18n.t("login.not_enabled_second_factor_method"))
          expect(result.used_2fa_method).to eq(nil)
        end
      end
    end

    context "when method selected is Security Keys" do
      let(:method) { UserSecondFactor.methods[:security_key] }

      before do
        simulate_localhost_webauthn_challenge
        DiscourseWebauthn.stage_challenge(user, server_session)
      end

      context "when security key params are valid" do
        let(:params) do
          { second_factor_token: valid_security_key_auth_post_data, second_factor_method: method }
        end

        it "returns OK" do
          expect(user.authenticate_second_factor(params, server_session).ok).to eq(true)
        end

        it "sets used_2fa_method to security keys" do
          expect(user.authenticate_second_factor(params, server_session).used_2fa_method).to eq(
            UserSecondFactor.methods[:security_key],
          )
        end

        it "returns an error when the user does not have security keys enabled" do
          user.security_keys.destroy_all
          result = user.authenticate_second_factor(params, server_session)
          expect(result.ok).to eq(false)
          expect(result.error).to eq(I18n.t("login.not_enabled_second_factor_method"))
          expect(result.used_2fa_method).to eq(nil)
        end
      end
    end

    context "when method selected is Backup Codes" do
      let(:method) { UserSecondFactor.methods[:backup_codes] }

      before { Fabricate(:user_second_factor_backup, user: user) }

      context "when backup code params are provided" do
        let(:params) { { second_factor_token: "iAmValidBackupCode", second_factor_method: method } }

        it "validates enabled backup codes" do
          expect(user.authenticate_second_factor(params, server_session).ok).to eq(true)
        end

        it "sets used_2fa_method to backup codes" do
          expect(user.authenticate_second_factor(params, server_session).used_2fa_method).to eq(
            UserSecondFactor.methods[:backup_codes],
          )
        end

        it "returns an error when backup codes are disabled" do
          user.user_second_factors.backup_codes.destroy_all
          result = user.authenticate_second_factor(params, server_session)
          expect(result.ok).to eq(false)
          expect(result.error).to eq(I18n.t("login.not_enabled_second_factor_method"))
          expect(result.used_2fa_method).to eq(nil)
        end
      end
    end

    context "when no totp params are provided" do
      let(:params) do
        {
          second_factor_token: valid_security_key_auth_post_data,
          second_factor_method: UserSecondFactor.methods[:security_key],
        }
      end

      it "validates the security key OK" do
        expect(user.authenticate_second_factor(params, server_session).ok).to eq(true)
      end

      it "sets used_2fa_method to security keys" do
        expect(user.authenticate_second_factor(params, server_session).used_2fa_method).to eq(
          UserSecondFactor.methods[:security_key],
        )
      end
    end

    context "when totp params are provided" do
      let(:params) do
        {
          second_factor_token: user.user_second_factors.totps.first.totp_object.now,
          second_factor_method: UserSecondFactor.methods[:totp],
        }
      end

      it "validates totp OK" do
        expect(user.authenticate_second_factor(params, server_session).ok).to eq(true)
      end

      it "sets used_2fa_method to totp" do
        expect(user.authenticate_second_factor(params, server_session).used_2fa_method).to eq(
          UserSecondFactor.methods[:totp],
        )
      end
    end
  end
end
