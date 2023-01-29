# frozen_string_literal: true

RSpec.describe SecondFactor::AuthManager do
  fab!(:user) { Fabricate(:user) }
  let(:guardian) { Guardian.new(user) }
  fab!(:user_totp) { Fabricate(:user_second_factor_totp, user: user) }

  def create_request(request_method: "GET", path: "/")
    ActionDispatch::TestRequest.create({ "REQUEST_METHOD" => request_method, "PATH_INFO" => path })
  end

  def create_manager(action)
    SecondFactor::AuthManager.new(guardian, action)
  end

  def create_action(request = nil)
    request ||= create_request
    TestSecondFactorAction.new(guardian, request)
  end

  def stage_challenge(successful:)
    request = create_request(request_method: "POST", path: "/abc/xyz")
    action = create_action(request)
    action.expects(:no_second_factors_enabled!).never
    action
      .expects(:second_factor_auth_required!)
      .with({ random_param: "hello" })
      .returns({ callback_params: { call_me_back: 4314 } })
      .once
    manager = create_manager(action)
    secure_session = {}
    expect { manager.run!(request, { random_param: "hello" }, secure_session) }.to raise_error(
      SecondFactor::AuthManager::SecondFactorRequired,
    ) do |ex|
      expect(ex.nonce).to be_present
    end

    challenge =
      JSON.parse(secure_session["current_second_factor_auth_challenge"]).deep_symbolize_keys

    if successful
      challenge[:successful] = true
      secure_session["current_second_factor_auth_challenge"] = challenge.to_json
    end
    [challenge[:nonce], secure_session]
  end

  describe "#allow_backup_codes!" do
    it "adds the backup codes method to the allowed methods set" do
      manager = create_manager(create_action)
      expect(manager.allowed_methods).not_to include(UserSecondFactor.methods[:backup_codes])
      manager.allow_backup_codes!
      expect(manager.allowed_methods).to include(UserSecondFactor.methods[:backup_codes])
    end
  end

  describe "#run!" do
    context "when the user does not have a suitable 2FA method" do
      before { user_totp.destroy! }

      it "calls the no_second_factors_enabled! method of the action" do
        action = create_action
        action.expects(:no_second_factors_enabled!).with({ hello_world: 331 }).once
        action.expects(:second_factor_auth_required!).never
        action.expects(:second_factor_auth_completed!).never
        manager = create_manager(action)
        manager.run!(create_request, { hello_world: 331 }, {})
      end
    end

    it "initiates the 2FA process and stages a challenge in secure session when there is no nonce in params" do
      request = create_request(request_method: "POST", path: "/abc/xyz")
      action = create_action(request)
      action.expects(:no_second_factors_enabled!).never
      action
        .expects(:second_factor_auth_required!)
        .with({ expect_me: 131 })
        .returns(
          callback_params: {
            call_me_back: 4314,
          },
          redirect_url: "/gg",
          description: "hello world!",
        )
        .once
      action.expects(:second_factor_auth_completed!).never
      manager = create_manager(action)
      secure_session = {}
      expect { manager.run!(request, { expect_me: 131 }, secure_session) }.to raise_error(
        SecondFactor::AuthManager::SecondFactorRequired,
      )
      json = secure_session["current_second_factor_auth_challenge"]
      challenge = JSON.parse(json).deep_symbolize_keys
      expect(challenge[:nonce]).to be_present
      expect(challenge[:callback_method]).to eq("POST")
      expect(challenge[:callback_path]).to eq("/abc/xyz")
      expect(challenge[:redirect_url]).to eq("/gg")
      expect(challenge[:allowed_methods]).to eq(manager.allowed_methods.to_a)
      expect(challenge[:callback_params]).to eq({ call_me_back: 4314 })
      expect(challenge[:description]).to eq("hello world!")
    end

    it "prefers callback_method and callback_path from the output of the action's second_factor_auth_required! method if they're present" do
      request = create_request(request_method: "POST", path: "/abc/xyz")
      action = create_action(request)
      action
        .expects(:second_factor_auth_required!)
        .with({})
        .returns(
          callback_params: {
            call_me_back: 4314,
          },
          callback_method: "PUT",
          callback_path: "/test/443",
        )
        .once
      manager = create_manager(action)
      secure_session = {}
      expect { manager.run!(request, {}, secure_session) }.to raise_error(
        SecondFactor::AuthManager::SecondFactorRequired,
      )
      json = secure_session["current_second_factor_auth_challenge"]
      challenge = JSON.parse(json).deep_symbolize_keys
      expect(challenge[:callback_method]).to eq("PUT")
      expect(challenge[:callback_path]).to eq("/test/443")
    end

    it "calls the second_factor_auth_completed! method of the action if the challenge is successful and not expired" do
      nonce, secure_session = stage_challenge(successful: true)

      request = create_request(request_method: "POST", path: "/abc/xyz")
      action = create_action(request)

      action.expects(:no_second_factors_enabled!).never
      action.expects(:second_factor_auth_required!).never
      action.expects(:second_factor_auth_completed!).with({ call_me_back: 4314 }).once
      manager = create_manager(action)
      manager.run!(request, { second_factor_nonce: nonce }, secure_session)
    end

    it "does not call the second_factor_auth_completed! method of the action if the challenge is not marked successful" do
      nonce, secure_session = stage_challenge(successful: false)

      request = create_request(request_method: "POST", path: "/abc/xyz")
      action = create_action(request)
      action.expects(:no_second_factors_enabled!).never
      action.expects(:second_factor_auth_required!).never
      action.expects(:second_factor_auth_completed!).never
      manager = create_manager(action)
      expect {
        manager.run!(request, { second_factor_nonce: nonce }, secure_session)
      }.to raise_error(SecondFactor::BadChallenge) do |ex|
        expect(ex.error_translation_key).to eq("second_factor_auth.challenge_not_completed")
      end
    end

    it "does not call the second_factor_auth_completed! method of the action if the challenge is expired" do
      nonce, secure_session = stage_challenge(successful: true)

      request = create_request(request_method: "POST", path: "/abc/xyz")
      action = create_action(request)
      action.expects(:no_second_factors_enabled!).never
      action.expects(:second_factor_auth_required!).never
      action.expects(:second_factor_auth_completed!).never
      manager = create_manager(action)

      freeze_time (SecondFactor::AuthManager::MAX_CHALLENGE_AGE + 1.minute).from_now
      expect {
        manager.run!(request, { second_factor_nonce: nonce }, secure_session)
      }.to raise_error(SecondFactor::BadChallenge) do |ex|
        expect(ex.error_translation_key).to eq("second_factor_auth.challenge_expired")
      end
    end

    it "calls second_factor_auth_skipped! if skip_second_factor_auth? return true" do
      action = create_action
      params = { a: 1 }
      action.expects(:skip_second_factor_auth?).with(params).returns(true).once
      action.expects(:second_factor_auth_skipped!).with(params).once
      action.expects(:no_second_factors_enabled!).never
      action.expects(:second_factor_auth_required!).never
      action.expects(:second_factor_auth_completed!).never
      manager = create_manager(action)
      manager.run!(action.request, params, {})
    end

    it "doesn't call second_factor_auth_skipped! if skip_second_factor_auth? return false" do
      action = create_action
      params = { a: 1 }
      action.expects(:skip_second_factor_auth?).with(params).returns(false).once
      action.expects(:second_factor_auth_skipped!).never
      action.expects(:no_second_factors_enabled!).never
      action.expects(:second_factor_auth_required!).with(params).returns({}).once
      action.expects(:second_factor_auth_completed!).never
      manager = create_manager(action)
      expect { manager.run!(action.request, params, {}) }.to raise_error(
        SecondFactor::AuthManager::SecondFactorRequired,
      ) do |ex|
        expect(ex.nonce).to be_present
      end
    end

    context "with returned results object" do
      it "has the correct status and contains the return value of the action hook that's called" do
        action = create_action
        action.expects(:skip_second_factor_auth?).with({}).returns(true).once
        action.expects(:second_factor_auth_skipped!).with({}).returns("yeah whatever").once
        manager = create_manager(action)
        results = manager.run!(action.request, {}, {})
        expect(results.data).to eq("yeah whatever")
        expect(results.second_factor_auth_skipped?).to eq(true)

        nonce, secure_session = stage_challenge(successful: true)
        request = create_request(request_method: "POST", path: "/abc/xyz")
        action = create_action(request)
        action
          .expects(:second_factor_auth_completed!)
          .with({ call_me_back: 4314 })
          .returns({ eviltrout: "goodbye :(" })
          .once
        manager = create_manager(action)
        results = manager.run!(request, { second_factor_nonce: nonce }, secure_session)
        expect(results.data).to eq({ eviltrout: "goodbye :(" })
        expect(results.second_factor_auth_completed?).to eq(true)

        user_totp.destroy!
        action = create_action
        action.expects(:no_second_factors_enabled!).with({}).returns("NOTHING WORKS").once
        manager = create_manager(action)
        results = manager.run!(action.request, {}, {})
        expect(results.data).to eq("NOTHING WORKS")
        expect(results.no_second_factors_enabled?).to eq(true)
      end
    end
  end
end
