require 'rails_helper'

RSpec.describe SecondFactorManager do
  let(:user_second_factor_totp) { Fabricate(:user_second_factor_totp) }
  let(:user) { user_second_factor_totp.user }
  let(:another_user) { Fabricate(:user) }

  let(:user_second_factor_backup) { Fabricate(:user_second_factor_backup) }
  let(:user_backup) {  user_second_factor_backup.user }

  describe '#totp' do
    it 'should return the right data' do
      totp = nil

      expect do
        totp = another_user.totp
      end.to change { UserSecondFactor.count }.by(1)

      expect(totp.issuer).to eq(SiteSetting.title)
      expect(totp.secret).to eq(another_user.reload.user_second_factors.totp.data)
    end
  end

  describe '#create_totp' do
    it 'should create the right record' do
      second_factor = another_user.create_totp(enabled: true)

      expect(second_factor.method).to eq(UserSecondFactor.methods[:totp])
      expect(second_factor.data).to be_present
      expect(second_factor.enabled).to eq(true)
    end

    describe 'when user has a second factor' do
      it 'should return nil' do
        expect(user.create_totp).to eq(nil)
      end
    end
  end

  describe '#totp_provisioning_uri' do
    it 'should return the right uri' do
      expect(user.totp_provisioning_uri).to eq(
        "otpauth://totp/#{SiteSetting.title}:#{user.email}?secret=#{user_second_factor_totp.data}&issuer=#{SiteSetting.title}"
      )
    end
  end

  describe '#authenticate_totp' do
    it 'should be able to authenticate a token' do
      freeze_time do
        expect(user.user_second_factors.totp.last_used).to eq(nil)

        token = user.totp.now

        expect(user.authenticate_totp(token)).to eq(true)
        expect(user.user_second_factors.totp.last_used).to eq(DateTime.now)
        expect(user.authenticate_totp(token)).to eq(false)
      end
    end

    describe 'when token is blank' do
      it 'should be false' do
        expect(user.authenticate_totp(nil)).to eq(false)
        expect(user.user_second_factors.totp.last_used).to eq(nil)
      end
    end

    describe 'when token is invalid' do
      it 'should be false' do
        expect(user.authenticate_totp('111111')).to eq(false)
        expect(user.user_second_factors.totp.last_used).to eq(nil)
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
        user.user_second_factors.totp.update!(enabled: false)
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
end
