require 'rails_helper'

RSpec.describe SecondFactorController, type: :controller do
  # featheredtoast-todo also write qunit tests.
  describe '.create' do

    let(:user) { Fabricate(:user) }

    describe 'create 2fa request' do
      it 'fails on incorrect password' do
        post :create, params: {
               login: user.username, password: 'wrongpassword'
             }, format: :json
        expect(JSON.parse(response.body)['error']).to eq(I18n.t("login.incorrect_username_email_or_password"))
      end

      it 'succeeds on correct password' do
        post :create, params: {
               login: user.username, password: 'myawesomepassword'
             }, format: :json
        expect(JSON.parse(response.body).keys).to contain_exactly('key', 'qr')
      end
    end
  end

  describe '.update' do
    let(:user) { Fabricate(:user) }

    context 'when user has totp setup' do
      second_factor_data = "rcyryaqage3jexfj"
      before do
        user.user_second_factor = UserSecondFactor.create(user_id: user.id, method: "totp", data: second_factor_data)
      end

      it 'errors on incorrect code' do
        post :update, params: {
               username: user.username,
               token: '000000',
               enable: 'true'
             }, format: :json
        expect(JSON.parse(response.body)['error']).to eq(I18n.t("login.invalid_second_factor_code"))
        user.reload
      end

      it 'can be enabled' do
        post :update, params: {
               username: user.username,
               token: ROTP::TOTP.new(second_factor_data).now,
               enable: 'true'
             }, format: :json
        expect(JSON.parse(response.body)['result']).to eq('ok')
        user.reload
        expect(user.user_second_factor.enabled).to be true
      end

      it 'can be disabled' do
        post :update, params: {
               username: user.username,
               enable: 'false',
               token: ROTP::TOTP.new(second_factor_data).now
             }, format: :json
        expect(JSON.parse(response.body)['result']).to eq('ok')
        user.reload
        expect(user.user_second_factor).to be_nil
      end
    end
  end

end
