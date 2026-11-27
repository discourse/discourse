# frozen_string_literal: true

RSpec.describe SecondFactor::AuthManager do
  fab!(:user)
  let(:guardian) { Guardian.new(user) }

  fab!(:user_totp) { Fabricate(:user_second_factor_totp, user: user) }

  def create_request(request_method: "GET", path: "/")
    ActionDispatch::TestRequest.create({ "REQUEST_METHOD" => request_method, "PATH_INFO" => path })
  end

  def create_manager(action)
    SecondFactor::AuthManager.new(guardian, action, target_user: user)
  end

  def create_action(request = nil)
    request ||= create_request
    TestSecondFactorAction.new(guardian, request, target_user: user)
  end

  def stage_challenge(successful:, used_2fa_method: nil)
    request = create_request(request_method: "POST", path: "/abc/xyz")
    action = create_action(request)
    action.expects(:no_second_factors_enabled!).never
    action
      .expects(:second_factor_auth_required!)
      .with({ random_param: "hello" })
      .returns({ callback_params: { call_me_back: 4314 } })
      .once
    manager = create_manager(action)
    server_session = ServerSession.new(SecureRandom.hex)
    nonce = start_challenge(manager, request, { random_param: "hello" }, server_session)
    if successful
      described_class.mark_challenge_successful!(
        find_challenge(nonce, server_session),
        server_session:,
        used_2fa_method:,
      )
    end
    [nonce, server_session]
  end

  def start_challenge(manager, request, params, server_session)
    manager.run!(request, params, server_session)
  rescue SecondFactor::AuthManager::SecondFactorRequired => error
    error.nonce
  end

  def find_challenge(nonce, server_session)
    described_class.find_second_factor_challenge(
      nonce:,
      server_session:,
      current_user: user,
      request: create_request,
    )
  end

  describe "#allowed_methods" do
    it "allows totp, security keys and passkeys by default" do
      manager = create_manager(create_action)
      expect(manager.allowed_methods).to contain_exactly(
        UserSecondFactor.methods[:totp],
        UserSecondFactor.methods[:security_key],
        UserSecondFactor.methods[:passkey],
      )
    end
  end

  describe "#allow_backup_codes!" do
    it "adds the backup codes method to the allowed methods set" do
      manager = create_manager(create_action)
      expect(manager.allowed_methods).not_to include(UserSecondFactor.methods[:backup_codes])
      manager.allow_backup_codes!
      expect(manager.allowed_methods).to include(UserSecondFactor.methods[:backup_codes])
    end
  end

  describe ".mark_challenge_successful!" do
    it "records used_2fa_method on the verified challenge when provided" do
      nonce, server_session =
        stage_challenge(successful: true, used_2fa_method: UserSecondFactor.methods[:totp])
      challenge = find_challenge(nonce, server_session)
      expect(challenge[:successful]).to eq(true)
      expect(challenge[:used_2fa_method]).to eq(UserSecondFactor.methods[:totp])
    end
  end

  describe ".find_second_factor_challenge" do
    it "binds challenges to the initiating user and token" do
      nonce, server_session = stage_challenge(successful: false)
      other_user = Fabricate(:user)
      other_request = create_request

      expect do
        described_class.find_second_factor_challenge(
          nonce:,
          server_session:,
          current_user: other_user,
          request: other_request,
        )
      end.to raise_error(SecondFactor::BadChallenge) { |error|
        expect(error.status_code).to eq(404)
      }

      token = UserAuthToken.generate!(user_id: user.id)
      request_with_token = create_request
      request_with_token.env[Auth::DefaultCurrentUserProvider::USER_TOKEN_KEY] = token

      expect do
        described_class.find_second_factor_challenge(
          nonce:,
          server_session:,
          current_user: user,
          request: request_with_token,
        )
      end.to raise_error(SecondFactor::BadChallenge) { |error|
        expect(error.status_code).to eq(404)
      }
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

    it "initiates the 2FA process and stages a challenge in server session when there is no nonce in params" do
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
      server_session = ServerSession.new(SecureRandom.hex)
      nonce = start_challenge(manager, request, { expect_me: 131 }, server_session)
      challenge = find_challenge(nonce, server_session)
      expect(challenge[:nonce]).to be_present
      expect(challenge[:callback_method]).to eq("POST")
      expect(challenge[:callback_path]).to eq("/abc/xyz")
      expect(challenge[:redirect_url]).to eq("/gg")
      expect(challenge[:allowed_methods]).to eq(manager.allowed_methods.to_a)
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
      server_session = ServerSession.new(SecureRandom.hex)
      nonce = start_challenge(manager, request, {}, server_session)
      challenge = find_challenge(nonce, server_session)
      expect(challenge[:callback_method]).to eq("PUT")
      expect(challenge[:callback_path]).to eq("/test/443")
    end

    it "calls the second_factor_auth_completed! method of the action if the challenge is successful and not expired" do
      nonce, server_session = stage_challenge(successful: true)

      request = create_request(request_method: "POST", path: "/abc/xyz")
      action = create_action(request)

      action.expects(:no_second_factors_enabled!).never
      action.expects(:second_factor_auth_required!).never
      action.expects(:second_factor_auth_completed!).with({ call_me_back: 4314 }).once
      manager = create_manager(action)
      manager.run!(request, { second_factor_nonce: nonce }, server_session)
    end

    it "rejects a late verification of a superseded challenge" do
      old_nonce, server_session = stage_challenge(successful: false)
      old_challenge = find_challenge(old_nonce, server_session)
      request = create_request
      new_nonce =
        start_challenge(create_manager(create_action(request)), request, {}, server_session)

      expect do
        described_class.mark_challenge_successful!(old_challenge, server_session:)
      end.to raise_error(SecondFactor::BadChallenge)
      expect(find_challenge(new_nonce, server_session)).not_to include(successful: true)
    end

    it "rejects a verified nonce issued for a different action without consuming it" do
      nonce, server_session = stage_challenge(successful: true)
      request = create_request(request_method: "POST", path: "/abc/xyz")
      other_action = SecondFactor::Actions::ConfirmEmail.new(guardian, request, target_user: user)

      expect do
        create_manager(other_action).run!(request, { second_factor_nonce: nonce }, server_session)
      end.to raise_error(SecondFactor::BadChallenge) { |error|
        expect(error.status_code).to eq(404)
      }

      action = create_action(request)
      result = create_manager(action).run!(request, { second_factor_nonce: nonce }, server_session)
      expect(result).to be_second_factor_auth_completed
    end

    it "rejects redemption if a newer challenge starts after the verified nonce is read" do
      nonce, server_session = stage_challenge(successful: true)
      request = create_request(request_method: "POST", path: "/abc/xyz")
      action = create_action(request)
      replacement_nonce = nil
      action
        .stubs(:challenge_scope)
        .with do
          replacement_nonce =
            start_challenge(create_manager(create_action(request)), request, {}, server_session)
          true
        end
        .returns(nil)

      expect do
        create_manager(action).run!(request, { second_factor_nonce: nonce }, server_session)
      end.to raise_error(SecondFactor::BadChallenge) { |error|
        expect(error.status_code).to eq(404)
      }
      expect(find_challenge(replacement_nonce, server_session)).not_to include(successful: true)
    end

    it "redeems a verified nonce only once across concurrent continuations" do
      nonce, server_session = stage_challenge(successful: true)
      request = create_request(request_method: "POST", path: "/abc/xyz")
      ready = Queue.new
      proceed = Queue.new
      continuations =
        Array.new(2) do
          action = create_action(request)
          action
            .stubs(:challenge_scope)
            .with do
              ready << true
              proceed.pop(timeout: 5)
            end
            .returns(nil)

          Thread.new do
            create_manager(action).run!(
              request,
              { second_factor_nonce: nonce },
              server_session,
            ).second_factor_auth_completed?
          rescue SecondFactor::BadChallenge => error
            error.status_code
          end
        end

      2.times { expect(ready.pop(timeout: 5)).to eq(true) }
      2.times { proceed << true }
      expect(continuations.map(&:value)).to contain_exactly(true, 404)
    end

    it "does not call the second_factor_auth_completed! method of the action if the challenge is not marked successful" do
      nonce, server_session = stage_challenge(successful: false)

      request = create_request(request_method: "POST", path: "/abc/xyz")
      action = create_action(request)
      action.expects(:no_second_factors_enabled!).never
      action.expects(:second_factor_auth_required!).never
      action.expects(:second_factor_auth_completed!).never
      manager = create_manager(action)
      expect {
        manager.run!(request, { second_factor_nonce: nonce }, server_session)
      }.to raise_error(SecondFactor::BadChallenge) do |ex|
        expect(ex.error_translation_key).to eq("second_factor_auth.challenge_not_completed")
      end
    end

    it "does not call the second_factor_auth_completed! method of the action if the challenge is expired" do
      nonce, server_session = stage_challenge(successful: true)

      request = create_request(request_method: "POST", path: "/abc/xyz")
      action = create_action(request)
      action.expects(:no_second_factors_enabled!).never
      action.expects(:second_factor_auth_required!).never
      action.expects(:second_factor_auth_completed!).never
      manager = create_manager(action)

      freeze_time (SecondFactor::AuthManager::MAX_CHALLENGE_AGE + 1.minute + 1.second).from_now
      expect {
        manager.run!(request, { second_factor_nonce: nonce }, server_session)
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
      expect {
        manager.run!(action.request, params, ServerSession.new(SecureRandom.hex))
      }.to raise_error(SecondFactor::AuthManager::SecondFactorRequired) do |ex|
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

        nonce, server_session = stage_challenge(successful: true)
        request = create_request(request_method: "POST", path: "/abc/xyz")
        action = create_action(request)
        action
          .expects(:second_factor_auth_completed!)
          .with({ call_me_back: 4314 })
          .returns({ eviltrout: "goodbye :(" })
          .once
        manager = create_manager(action)
        results = manager.run!(request, { second_factor_nonce: nonce }, server_session)
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
