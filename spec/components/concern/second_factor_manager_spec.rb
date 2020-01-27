# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SecondFactorManager do
  fab!(:user) { Fabricate(:user) }
  fab!(:user_second_factor_totp) { Fabricate(:user_second_factor_totp, user: user) }
  fab!(:user_security_key) do
    Fabricate(
      :user_security_key,
      user: user,
      public_key: valid_security_key_data[:public_key],
      credential_id: valid_security_key_data[:credential_id]
    )
  end
  fab!(:another_user) { Fabricate(:user) }

  fab!(:user_second_factor_backup) { Fabricate(:user_second_factor_backup) }
  let(:user_backup) {  user_second_factor_backup.user }

  describe '#totp' do
    it 'should return the right data' do
      totp = nil

      expect do
        totp = another_user.create_totp(enabled: true)
      end.to change { UserSecondFactor.count }.by(1)

      expect(totp.totp_object.issuer).to eq(SiteSetting.title)
      expect(totp.totp_object.secret).to eq(another_user.reload.user_second_factors.totps.first.data)
    end
  end

  describe '#create_totp' do
    it 'should create the right record' do
      second_factor = another_user.create_totp(enabled: true)

      expect(second_factor.method).to eq(UserSecondFactor.methods[:totp])
      expect(second_factor.data).to be_present
      expect(second_factor.enabled).to eq(true)
    end
  end

  describe '#totp_provisioning_uri' do
    it 'should return the right uri' do
      expect(user.user_second_factors.totps.first.totp_provisioning_uri).to eq(
        "otpauth://totp/#{SiteSetting.title}:#{user.email}?secret=#{user_second_factor_totp.data}&issuer=#{SiteSetting.title}"
      )
    end
  end

  describe '#authenticate_totp' do
    it 'should be able to authenticate a token' do
      freeze_time do
        expect(user.user_second_factors.totps.first.last_used).to eq(nil)

        token = user.user_second_factors.totps.first.totp_object.now

        expect(user.authenticate_totp(token)).to eq(true)
        expect(user.user_second_factors.totps.first.last_used).to eq_time(DateTime.now)
        expect(user.authenticate_totp(token)).to eq(false)
      end
    end

    describe 'when token is blank' do
      it 'should be false' do
        expect(user.authenticate_totp(nil)).to eq(false)
        expect(user.user_second_factors.totps.first.last_used).to eq(nil)
      end
    end

    describe 'when token is invalid' do
      it 'should be false' do
        expect(user.authenticate_totp('111111')).to eq(false)
        expect(user.user_second_factors.totps.first.last_used).to eq(nil)
      end
    end
  end

  describe '#totp_enabled?' do
    describe 'when user does not have a second factor record' do
      it 'should return false' do
        expect(another_user.totp_enabled?).to eq(false)
      end
    end

    describe "when user's second factor record is disabled" do
      it 'should return false' do
        disable_totp
        expect(user.totp_enabled?).to eq(false)
      end
    end

    describe "when user's second factor record is enabled" do
      it 'should return true' do
        expect(user.totp_enabled?).to eq(true)
      end
    end

    describe 'when SSO is enabled' do
      it 'should return false' do
        SiteSetting.sso_url = 'http://someurl.com'
        SiteSetting.enable_sso = true

        expect(user.totp_enabled?).to eq(false)
      end
    end

    describe 'when local login is disabled' do
      it 'should return false' do
        SiteSetting.enable_local_logins = false

        expect(user.totp_enabled?).to eq(false)
      end
    end
  end

  describe "#has_multiple_second_factor_methods?" do
    context "when security keys and totp are enabled" do
      it "retrns true" do
        expect(user.has_multiple_second_factor_methods?).to eq(true)
      end
    end

    context "if the totp gets disabled" do
      it "retrns false" do
        disable_totp
        expect(user.has_multiple_second_factor_methods?).to eq(false)
      end
    end

    context "if the security key gets disabled" do
      it "retrns false" do
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

  describe "#authenticate_second_factor" do
    let(:params) { {} }
    let(:secure_session) { {} }

    context "when neither security keys nor totp/backup codes are enabled" do
      before do
        disable_security_key && disable_totp
      end
      it "returns OK, because it doesn't need to authenticate" do
        expect(user.authenticate_second_factor(params, secure_session).ok).to eq(true)
      end
    end

    context "when only security key is enabled" do
      before do
        disable_totp
        simulate_localhost_webauthn_challenge
        Webauthn.stage_challenge(user, secure_session)
      end

      context "when security key params are valid" do
        let(:params) { { second_factor_token: valid_security_key_auth_post_data, second_factor_method: UserSecondFactor.methods[:security_key] } }
        it "returns OK" do
          expect(user.authenticate_second_factor(params, secure_session).ok).to eq(true)
        end
      end

      context "when security key params are invalid" do
        let(:params) do
          {
            second_factor_token: {
              signature: 'bad',
              clientData: 'bad',
              authenticatorData: 'bad',
              credentialId: 'bad'
            },
            second_factor_method: UserSecondFactor.methods[:security_key]
          }
        end
        it "returns not OK" do
          result = user.authenticate_second_factor(params, secure_session)
          expect(result.ok).to eq(false)
          expect(result.error).to eq(I18n.t("webauthn.validation.not_found_error"))
        end
      end
    end

    context "when only totp is enabled" do
      before do
        disable_security_key
      end

      context "when totp is valid" do
        let(:params) do
          {
            second_factor_token: user.user_second_factors.totps.first.totp_object.now,
            second_factor_method: UserSecondFactor.methods[:totp]
          }
        end
        it "returns OK" do
          expect(user.authenticate_second_factor(params, secure_session).ok).to eq(true)
        end
      end

      context "when totp is invalid" do
        let(:params) do
          {
            second_factor_token: "blah",
            second_factor_method: UserSecondFactor.methods[:totp]
          }
        end
        it "returns not OK" do
          result = user.authenticate_second_factor(params, secure_session)
          expect(result.ok).to eq(false)
          expect(result.error).to eq(I18n.t("login.invalid_second_factor_code"))
        end
      end
    end

    context "when both security keys and totp are enabled" do
      let(:invalid_method) { 4 }
      let(:method) { invalid_method }

      before do
        simulate_localhost_webauthn_challenge
        Webauthn.stage_challenge(user, secure_session)
      end

      context "when method selected is invalid" do
        it "returns an error" do
          result = user.authenticate_second_factor(params, secure_session)
          expect(result.ok).to eq(false)
          expect(result.error).to eq(I18n.t("login.invalid_second_factor_method"))
        end
      end

      context "when method selected is TOTP" do
        let(:method) { UserSecondFactor.methods[:totp] }
        let(:token) { user.user_second_factors.totps.first.totp_object.now }

        context "when totp params are provided" do
          let(:params) do
            {
              second_factor_token: token,
              second_factor_method: method
            }
          end

          it "validates totp OK" do
            expect(user.authenticate_second_factor(params, secure_session).ok).to eq(true)
          end

          context "when the user does not have TOTP enabled" do
            let(:token) { 'test' }
            before do
              user.totps.destroy_all
            end

            it "returns an error" do
              result = user.authenticate_second_factor(params, secure_session)
              expect(result.ok).to eq(false)
              expect(result.error).to eq(I18n.t("login.not_enabled_second_factor_method"))
            end
          end
        end
      end

      context "when method selected is Security Keys" do
        let(:method) { UserSecondFactor.methods[:security_key] }

        before do
          simulate_localhost_webauthn_challenge
          Webauthn.stage_challenge(user, secure_session)
        end

        context "when security key params are valid" do
          let(:params) { { second_factor_token: valid_security_key_auth_post_data, second_factor_method: method } }
          it "returns OK" do
            expect(user.authenticate_second_factor(params, secure_session).ok).to eq(true)
          end

          context "when the user does not have security keys enabled" do
            before do
              user.security_keys.destroy_all
            end

            it "returns an error" do
              result = user.authenticate_second_factor(params, secure_session)
              expect(result.ok).to eq(false)
              expect(result.error).to eq(I18n.t("login.not_enabled_second_factor_method"))
            end
          end
        end
      end

      context "when method selected is Backup Codes" do
        let(:method) { UserSecondFactor.methods[:backup_codes] }
        let!(:backup_code) { Fabricate(:user_second_factor_backup, user: user) }

        context "when backup code params are provided" do
          let(:params) do
            {
              second_factor_token: 'iAmValidBackupCode',
              second_factor_method: method
            }
          end

          context "when backup codes enabled" do
            it "validates codes OK" do
              expect(user.authenticate_second_factor(params, secure_session).ok).to eq(true)
            end
          end

          context "when backup codes disabled" do
            before do
              user.user_second_factors.backup_codes.destroy_all
            end

            it "returns an error" do
              result = user.authenticate_second_factor(params, secure_session)
              expect(result.ok).to eq(false)
              expect(result.error).to eq(I18n.t("login.not_enabled_second_factor_method"))
            end
          end
        end
      end

      context "when no totp params are provided" do
        let(:params) { { second_factor_token: valid_security_key_auth_post_data, second_factor_method: UserSecondFactor.methods[:security_key] } }

        it "validates the security key OK" do
          expect(user.authenticate_second_factor(params, secure_session).ok).to eq(true)
        end
      end

      context "when totp params are provided" do
        let(:params) do
          {
            second_factor_token: user.user_second_factors.totps.first.totp_object.now,
            second_factor_method: UserSecondFactor.methods[:totp]
          }
        end

        it "validates totp OK" do
          expect(user.authenticate_second_factor(params, secure_session).ok).to eq(true)
        end
      end
    end
  end

  context 'backup codes' do
    describe '#generate_backup_codes' do
      it 'should generate and store 10 backup codes' do
        backup_codes = user.generate_backup_codes

        expect(backup_codes.length).to be 10
        expect(user_backup.user_second_factors.backup_codes).to be_present
        expect(user_backup.user_second_factors.backup_codes.pluck(:method).uniq[0]).to eq(UserSecondFactor.methods[:backup_codes])
        expect(user_backup.user_second_factors.backup_codes.pluck(:enabled).uniq[0]).to eq(true)
      end
    end

    describe '#create_backup_codes' do
      it 'should create 10 backup code records' do
        raw_codes = Array.new(10) { SecureRandom.hex(8) }
        backup_codes = another_user.create_backup_codes(raw_codes)

        expect(another_user.user_second_factors.backup_codes.length).to be 10
      end
    end

    describe '#authenticate_backup_code' do
      it 'should be able to authenticate a backup code' do
        backup_code = "iAmValidBackupCode"

        expect(user_backup.authenticate_backup_code(backup_code)).to eq(true)
        expect(user_backup.authenticate_backup_code(backup_code)).to eq(false)
      end

      describe 'when code is blank' do
        it 'should be false' do
          expect(user_backup.authenticate_backup_code(nil)).to eq(false)
        end
      end

      describe 'when code is invalid' do
        it 'should be false' do
          expect(user_backup.authenticate_backup_code("notValidBackupCode")).to eq(false)
        end
      end
    end

    describe '#backup_codes_enabled?' do
      describe 'when user does not have a second factor backup enabled' do
        it 'should return false' do
          expect(another_user.backup_codes_enabled?).to eq(false)
        end
      end

      describe "when user's second factor backup codes have been used" do
        it 'should return false' do
          user_backup.user_second_factors.backup_codes.update_all(enabled: false)
          expect(user_backup.backup_codes_enabled?).to eq(false)
        end
      end

      describe "when user's second factor code is available" do
        it 'should return true' do
          expect(user_backup.backup_codes_enabled?).to eq(true)
        end
      end

      describe 'when SSO is enabled' do
        it 'should return false' do
          SiteSetting.sso_url = 'http://someurl.com'
          SiteSetting.enable_sso = true

          expect(user_backup.backup_codes_enabled?).to eq(false)
        end
      end

      describe 'when local login is disabled' do
        it 'should return false' do
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
