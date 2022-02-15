# frozen_string_literal: true

require 'rails_helper'

describe SecondFactor::AuthManager do
  fab!(:user) { Fabricate(:user) }
  fab!(:guardian) { Guardian.new(user) }
  fab!(:user_totp) { Fabricate(:user_second_factor_totp, user: user) }

  def create_request(request_method: "GET", path: "/")
    ActionDispatch::TestRequest.create({
      "REQUEST_METHOD" => request_method,
      "PATH_INFO" => path
    })
  end

  def create_manager(action)
    SecondFactor::AuthManager.new(guardian, action)
  end

  def create_action(callback_params = {}, redirect_path = nil)
    klass = Class.new(SecondFactor::Actions::Base) do
      attr_reader :called_methods
    end

    klass.define_method(:no_second_factors_enabled!) do |params|
      (@called_methods ||= []) << __method__
    end
    klass.define_method(:second_factor_auth_required!) do |params|
      (@called_methods ||= []) << __method__
      {
        callback_params: callback_params,
        redirect_path: redirect_path
      }
    end
    klass.define_method(:second_factor_auth_completed!) do |params|
      (@called_methods ||= []) << __method__
    end

    klass.new(guardian)
  end

  def stage_challenge(successful:)
    action = create_action({ call_me_back: 4314 })
    manager = create_manager(action)
    request = create_request(
      request_method: "POST",
      path: "/abc/xyz"
    )
    secure_session = {}
    begin
      manager.run!(request, {}, secure_session)
    rescue SecondFactor::AuthManager::SecondFactorRequired
      # expected
    end

    challenge = JSON
      .parse(secure_session["current_second_factor_auth_challenge"])
      .deep_symbolize_keys

    challenge[:successful] = successful
    secure_session["current_second_factor_auth_challenge"] = challenge.to_json
    [challenge[:nonce], secure_session]
  end

  describe '#allow_backup_codes!' do
    it 'adds the backup codes method to the allowed methods set' do
      manager = create_manager(create_action)
      expect(manager.allowed_methods).not_to include(
        UserSecondFactor.methods[:backup_codes]
      )
      manager.allow_backup_codes!
      expect(manager.allowed_methods).to include(
        UserSecondFactor.methods[:backup_codes]
      )
    end
  end

  describe '#run!' do
    context 'when the user does not have a suitable 2FA method' do
      before do
        user_totp.destroy!
      end

      it 'calls the no_second_factors_enabled! method of the action' do
        action = create_action
        manager = create_manager(action)
        manager.run!(create_request, {}, {})
        expect(action.called_methods).to contain_exactly(
          :no_second_factors_enabled!
        )
      end

      it 'calls the no_second_factors_enabled! method of the action even if a nonce is present in the params' do
        action = create_action
        manager = create_manager(action)
        manager.run!(create_request, { second_factor_nonce: SecureRandom.hex }, {})
        expect(action.called_methods).to contain_exactly(
          :no_second_factors_enabled!
        )
      end
    end

    it "initiates the 2FA process and stages a challenge in secure session when there is no nonce in params" do
      set_subfolder("/community")
      action = create_action({ call_me_back: 4314 })
      manager = create_manager(action)
      request = create_request(
        request_method: "POST",
        path: "/abc/xyz"
      )
      secure_session = {}
      expect {
        manager.run!(request, {}, secure_session)
      }.to raise_error(SecondFactor::AuthManager::SecondFactorRequired)
      expect(action.called_methods).to contain_exactly(
        :second_factor_auth_required!
      )
      json = secure_session["current_second_factor_auth_challenge"]
      challenge = JSON.parse(json).deep_symbolize_keys
      expect(challenge[:nonce]).to be_present
      expect(challenge[:callback_method]).to eq("POST")
      expect(challenge[:callback_path]).to eq("/abc/xyz")
      expect(challenge[:redirect_path]).to eq("/community/")
      expect(challenge[:allowed_methods]).to eq(manager.allowed_methods.to_a)
      expect(challenge[:callback_params]).to eq({ call_me_back: 4314 })
    end

    it "calls the second_factor_auth_completed! method of the action if the challenge is successful and not expired" do
      nonce, secure_session = stage_challenge(successful: true)

      action = create_action
      manager = create_manager(action)
      request = create_request(
        request_method: "POST",
        path: "/abc/xyz"
      )
      manager.run!(request, { second_factor_nonce: nonce }, secure_session)
      expect(action.called_methods).to contain_exactly(
        :second_factor_auth_completed!
      )
    end

    it "does not call the second_factor_auth_completed! method of the action if the challenge is not marked successful" do
      nonce, secure_session = stage_challenge(successful: false)

      action = create_action
      manager = create_manager(action)
      request = create_request(
        request_method: "POST",
        path: "/abc/xyz"
      )
      expect {
        manager.run!(request, { second_factor_nonce: nonce }, secure_session)
      }.to raise_error(SecondFactor::BadChallenge) do |ex|
        expect(ex.error_translation_key).to eq("second_factor_auth.challenge_not_completed")
      end
      expect(action.called_methods).to be_blank
    end

    it "does not call the second_factor_auth_completed! method of the action if the challenge is expired" do
      nonce, secure_session = stage_challenge(successful: true)

      action = create_action
      manager = create_manager(action)
      request = create_request(
        request_method: "POST",
        path: "/abc/xyz"
      )

      freeze_time 6.minutes.from_now
      expect {
        manager.run!(request, { second_factor_nonce: nonce }, secure_session)
      }.to raise_error(SecondFactor::BadChallenge) do |ex|
        expect(ex.error_translation_key).to eq("second_factor_auth.challenge_expired")
      end
      expect(action.called_methods).to be_blank
    end
  end
end
