require 'rails_helper'

RSpec.describe SecondFactorManager do
  let(:user_second_factor) { Fabricate(:user_second_factor) }
  let(:user) { user_second_factor.user }
  let(:another_user) { Fabricate(:user) }

  describe '#totp' do
    it 'should return the right data' do
      totp = nil

      expect do
        totp = another_user.totp
      end.to change { UserSecondFactor.count }.by(1)

      expect(totp.issuer).to eq(SiteSetting.title)
      expect(totp.secret).to eq(another_user.reload.user_second_factor.data)
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
        "otpauth://totp/#{SiteSetting.title}:#{user.email}?secret=#{user_second_factor.data}&issuer=#{SiteSetting.title}"
      )
    end
  end

  describe '#authenticate_totp' do
    it 'should be able to authenticate a token' do
      freeze_time do
        expect(user.user_second_factor.last_used).to eq(nil)

        token = user.totp.now

        expect(user.authenticate_totp(token)).to eq(true)
        expect(user.user_second_factor.last_used).to eq(DateTime.now)
        expect(user.authenticate_totp(token)).to eq(false)
      end
    end

    describe 'when token is blank' do
      it 'should be false' do
        expect(user.authenticate_totp(nil)).to eq(false)
        expect(user.user_second_factor.last_used).to eq(nil)
      end
    end

    describe 'when token is invalid' do
      it 'should be false' do
        expect(user.authenticate_totp('111111')).to eq(false)
        expect(user.user_second_factor.last_used).to eq(nil)
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
        user.user_second_factor.update!(enabled: false)
        expect(user.totp_enabled?).to eq(false)
      end
    end

    describe "when user's second factor record is enabled" do
      it 'should return true' do
        expect(user.totp_enabled?).to eq(true)
      end
    end
  end
end
