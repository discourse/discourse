# frozen_string_literal: true

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

  def create_action
    TestSecondFactorAction.new(guardian)
  end

  def stage_challenge(successful:)
    action = create_action
    action.expects(:no_second_factors_enabled!).never
    action
      .expects(:second_factor_auth_required!)
      .with({ random_param: 'hello' })
      .returns({ callback_params: { call_me_back: 4314 } })
      .once
    manager = create_manager(action)
    request = create_request(
      request_method: "POST",
      path: "/abc/xyz"
    )
    secure_session = {}
    begin
      manager.run!(request, { random_param: 'hello' }, secure_session)
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
        action.expects(:no_second_factors_enabled!).with({ hello_world: 331 }).once
        action.expects(:second_factor_auth_required!).never
        action.expects(:second_factor_auth_completed!).never
        manager = create_manager(action)
        manager.run!(create_request, { hello_world: 331 }, {})
      end

      it 'calls the no_second_factors_enabled! method of the action even if a nonce is present in the params' do
        action = create_action
        params = { second_factor_nonce: SecureRandom.hex }
        action.expects(:no_second_factors_enabled!).with(params).once
        action.expects(:second_factor_auth_required!).never
        action.expects(:second_factor_auth_completed!).never
        manager = create_manager(action)
        manager.run!(create_request, params, {})
      end
    end

    it "initiates the 2FA process and stages a challenge in secure session when there is no nonce in params" do
      action = create_action
      action.expects(:no_second_factors_enabled!).never
      action
        .expects(:second_factor_auth_required!)
        .with({ expect_me: 131 })
        .returns({ callback_params: { call_me_back: 4314 }, redirect_path: "/gg" })
        .once
      action.expects(:second_factor_auth_completed!).never
      manager = create_manager(action)
      request = create_request(
        request_method: "POST",
        path: "/abc/xyz"
      )
      secure_session = {}
      expect {
        manager.run!(request, { expect_me: 131 }, secure_session)
      }.to raise_error(SecondFactor::AuthManager::SecondFactorRequired)
      json = secure_session["current_second_factor_auth_challenge"]
      challenge = JSON.parse(json).deep_symbolize_keys
      expect(challenge[:nonce]).to be_present
      expect(challenge[:callback_method]).to eq("POST")
      expect(challenge[:callback_path]).to eq("/abc/xyz")
      expect(challenge[:redirect_path]).to eq("/gg")
      expect(challenge[:allowed_methods]).to eq(manager.allowed_methods.to_a)
      expect(challenge[:callback_params]).to eq({ call_me_back: 4314 })
    end

    it "sets the redirect_path to the root path if second_factor_auth_required! doesn't specify a redirect_path" do
      action = create_action
      action.expects(:no_second_factors_enabled!).never
      action
        .expects(:second_factor_auth_required!)
        .with({ expect_me: 131 })
        .returns({ callback_params: { call_me_back: 4314 } })
        .once
      action.expects(:second_factor_auth_completed!).never
      manager = create_manager(action)
      request = create_request(
        request_method: "POST",
        path: "/abc/xyz"
      )
      secure_session = {}
      expect {
        manager.run!(request, { expect_me: 131 }, secure_session)
      }.to raise_error(SecondFactor::AuthManager::SecondFactorRequired)
      json = secure_session["current_second_factor_auth_challenge"]
      challenge = JSON.parse(json).deep_symbolize_keys
      expect(challenge[:redirect_path]).to eq("/")

      set_subfolder("/community")
      action = create_action
      action.expects(:no_second_factors_enabled!).never
      action
        .expects(:second_factor_auth_required!)
        .with({ expect_me: 131 })
        .returns({ callback_params: { call_me_back: 4314 } })
        .once
      action.expects(:second_factor_auth_completed!).never
      manager = create_manager(action)
      request = create_request(
        request_method: "POST",
        path: "/abc/xyz"
      )
      secure_session = {}
      expect {
        manager.run!(request, { expect_me: 131 }, secure_session)
      }.to raise_error(SecondFactor::AuthManager::SecondFactorRequired)
      json = secure_session["current_second_factor_auth_challenge"]
      challenge = JSON.parse(json).deep_symbolize_keys
      expect(challenge[:redirect_path]).to eq("/community")
    end

    it "calls the second_factor_auth_completed! method of the action if the challenge is successful and not expired" do
      nonce, secure_session = stage_challenge(successful: true)

      action = create_action

      action.expects(:no_second_factors_enabled!).never
      action.expects(:second_factor_auth_required!).never
      action
        .expects(:second_factor_auth_completed!)
        .with({ call_me_back: 4314 })
        .once
      manager = create_manager(action)
      request = create_request(
        request_method: "POST",
        path: "/abc/xyz"
      )
      manager.run!(request, { second_factor_nonce: nonce }, secure_session)
    end

    it "does not call the second_factor_auth_completed! method of the action if the challenge is not marked successful" do
      nonce, secure_session = stage_challenge(successful: false)

      action = create_action
      action.expects(:no_second_factors_enabled!).never
      action.expects(:second_factor_auth_required!).never
      action.expects(:second_factor_auth_completed!).never
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
    end

    it "does not call the second_factor_auth_completed! method of the action if the challenge is expired" do
      nonce, secure_session = stage_challenge(successful: true)

      action = create_action
      action.expects(:no_second_factors_enabled!).never
      action.expects(:second_factor_auth_required!).never
      action.expects(:second_factor_auth_completed!).never
      manager = create_manager(action)
      request = create_request(
        request_method: "POST",
        path: "/abc/xyz"
      )

      freeze_time (SecondFactor::AuthManager::MAX_CHALLENGE_AGE + 1.minute).from_now
      expect {
        manager.run!(request, { second_factor_nonce: nonce }, secure_session)
      }.to raise_error(SecondFactor::BadChallenge) do |ex|
        expect(ex.error_translation_key).to eq("second_factor_auth.challenge_expired")
      end
    end
  end
end
