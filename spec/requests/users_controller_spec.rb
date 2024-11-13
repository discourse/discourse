# frozen_string_literal: true

require "rotp"

RSpec.describe UsersController do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:user1) do
    Fabricate(:user, username: "someusername", refresh_auto_groups: true, created_at: 6.minutes.ago)
  end
  fab!(:another_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:invitee) { Fabricate(:user) }
  fab!(:inviter) { Fabricate(:user) }

  fab!(:admin)
  fab!(:moderator)
  fab!(:inactive_user)

  # Unfortunately, there are tests that depend on the user being created too
  # late for fab! to work.
  let(:user_deferred) { Fabricate(:user, refresh_auto_groups: true) }

  describe "#full account registration flow" do
    it "will correctly handle honeypot and challenge" do
      get "/session/hp.json"
      expect(response.status).to eq(200)

      json = response.parsed_body

      params = {
        email: "jane@jane.com",
        name: "jane",
        username: "jane",
        password_confirmation: json["value"],
        challenge: json["challenge"].reverse,
        password: SecureRandom.hex,
      }

      secure_session = SecureSession.new(session["secure_session_id"])

      expect(secure_session[UsersController::HONEYPOT_KEY]).to eq(json["value"])
      expect(secure_session[UsersController::CHALLENGE_KEY]).to eq(json["challenge"])

      post "/u.json", params: params

      expect(response.status).to eq(200)

      jane = User.find_by(username: "jane")

      expect(jane.email).to eq("jane@jane.com")

      expect(secure_session[UsersController::HONEYPOT_KEY]).to eq(nil)
      expect(secure_session[UsersController::CHALLENGE_KEY]).to eq(nil)
    end
  end

  describe "#perform_account_activation" do
    let(:email_token) { Fabricate(:email_token, user: user_deferred) }

    before { UsersController.any_instance.stubs(:honeypot_or_challenge_fails?).returns(false) }

    context "with invalid token" do
      it "return success" do
        put "/u/activate-account/invalid-token"
        expect(response.status).to eq(422)
      end
    end

    context "with valid token" do
      context "with welcome message" do
        it "enqueues a welcome message if the user object indicates so" do
          SiteSetting.send_welcome_message = true
          user_deferred.update(active: false)
          put "/u/activate-account/#{email_token.token}"
          expect(response.status).to eq(200)
          expect(Jobs::SendSystemMessage.jobs.size).to eq(1)
          expect(Jobs::SendSystemMessage.jobs.first["args"].first["message_type"]).to eq(
            "welcome_user",
          )
        end

        it "doesn't enqueue the welcome message if the object returns false" do
          user_deferred.update(active: true)
          put "/u/activate-account/#{email_token.token}"
          expect(response.status).to eq(200)
          expect(Jobs::SendSystemMessage.jobs.size).to eq(0)
        end
      end

      context "with honeypot" do
        it "raises an error if the honeypot is invalid" do
          UsersController.any_instance.stubs(:honeypot_or_challenge_fails?).returns(true)
          put "/u/activate-account/#{email_token.token}"
          expect(response.status).to eq(403)
        end
      end

      context "with response" do
        it "correctly logs on user" do
          email_token

          events = DiscourseEvent.track_events { put "/u/activate-account/#{email_token.token}" }

          expect(events.map { |event| event[:event_name] }).to contain_exactly(
            :user_confirmed_email,
            :user_first_logged_in,
            :user_logged_in,
          )

          expect(response.status).to eq(200)

          data = JSON.parse(response.body)
          expect(data["needs_approval"]).to eq(false)

          expect(session[:current_user_id]).to be_present
        end
      end

      context "when user is not approved" do
        before { SiteSetting.must_approve_users = true }

        it "should return the right response" do
          put "/u/activate-account/#{email_token.token}"
          expect(response.status).to eq(200)

          data = JSON.parse(response.body)
          expect(data["needs_approval"]).to eq(true)

          expect(session[:current_user_id]).to be_blank
        end
      end

      context "when bootstrap mode is enabled" do
        before { SiteSetting.bootstrap_mode_enabled = true }

        it "adds the user to the user directory" do
          token = Fabricate(:email_token, user: inactive_user)

          expect do put "/u/activate-account/#{token.token}" end.to change {
            DirectoryItem.where(user_id: inactive_user.id).count
          }.by(DirectoryItem.period_types.count)

          expect(response.status).to eq(200)
        end
      end

      context "when bootstrap mode is disabled" do
        before { SiteSetting.bootstrap_mode_enabled = false }

        it "adds the user to the user directory" do
          token = Fabricate(:email_token, user: inactive_user)

          expect do put "/u/activate-account/#{token.token}" end.not_to change {
            DirectoryItem.where(user_id: inactive_user.id).count
          }

          expect(response.status).to eq(200)
        end
      end
    end

    context "when cookies contains a destination URL" do
      it "should redirect to the URL" do
        destination_url = "http://thisisasite.com/somepath"
        cookies[:destination_url] = destination_url

        put "/u/activate-account/#{email_token.token}"

        expect(response.status).to eq(200)
        expect(response.parsed_body["redirect_to"]).to eq(destination_url)
      end
    end

    context "when cookies does not contain a destination URL but users was invited to topic" do
      let(:invite) { Fabricate(:invite) }
      let(:topic) { Fabricate(:topic) }

      before do
        TopicInvite.create!(topic: topic, invite: invite)
        Fabricate(:invited_user, invite: invite, user: email_token.user)
        invite.reload
      end

      it "should redirect to the topic" do
        put "/u/activate-account/#{email_token.token}"

        expect(response.status).to eq(200)
        expect(response.parsed_body["redirect_to"]).to eq(topic.relative_url)
      end
    end
  end

  describe "#password_reset" do
    let(:token) { SecureRandom.hex }

    context "when login is required" do
      it "returns success" do
        SiteSetting.login_required = true
        get "/u/password-reset/#{token}"
        expect(response.status).to eq(200)
        expect(CGI.unescapeHTML(response.body)).to include(
          I18n.t("password_reset.no_token", base_url: Discourse.base_url),
        )
      end
    end

    context "with missing token" do
      it "disallows login" do
        get "/u/password-reset/#{token}"

        expect(response.status).to eq(200)

        expect(CGI.unescapeHTML(response.body)).to include(
          I18n.t("password_reset.no_token", base_url: Discourse.base_url),
        )

        expect(response.body).to_not have_tag(:script, with: { src: "/assets/application.js" })

        expect(session[:current_user_id]).to be_blank
      end

      it "responds with proper error message" do
        get "/u/password-reset/#{token}.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["message"]).to eq(
          I18n.t("password_reset.no_token", base_url: Discourse.base_url),
        )
        expect(session[:current_user_id]).to be_blank
      end
    end

    context "with invalid token" do
      it "disallows login" do
        get "/u/password-reset/ev!l_trout@!"

        expect(response.status).to eq(200)

        expect(CGI.unescapeHTML(response.body)).to include(
          I18n.t("password_reset.no_token", base_url: Discourse.base_url),
        )

        expect(response.body).to_not have_tag(:script, with: { src: "/assets/application.js" })

        expect(session[:current_user_id]).to be_blank
      end

      it "responds with proper error message" do
        put "/u/password-reset/evil_trout!.json", params: { password: "awesomeSecretPassword" }

        expect(response.status).to eq(200)
        expect(response.parsed_body["message"]).to eq(
          I18n.t("password_reset.no_token", base_url: Discourse.base_url),
        )
        expect(session[:current_user_id]).to be_blank
      end
    end

    context "with valid token" do
      let!(:user_auth_token) { UserAuthToken.generate!(user_id: user1.id) }
      let!(:email_token) do
        Fabricate(:email_token, user: user1, scope: EmailToken.scopes[:password_reset])
      end

      context "when rendered" do
        it "renders referrer never on get requests" do
          get "/u/password-reset/#{email_token.token}"
          expect(response.status).to eq(200)
          expect(response.body).to include('<meta name="referrer" content="never">')
        end
      end

      it "returns success" do
        events =
          DiscourseEvent.track_events do
            put "/u/password-reset/#{email_token.token}", params: { password: "hg9ow8yhg98o" }
          end

        expect(events.map { |event| event[:event_name] }).to contain_exactly(
          :user_logged_in,
          :user_first_logged_in,
          :user_confirmed_email,
        )

        expect(response.status).to eq(200)
        expect(response.body).to have_tag("div#data-preloaded") do |element|
          json = JSON.parse(element.current_scope.attribute("data-preloaded").value)
          expect(json["password_reset"]).to include(
            '{"is_developer":false,"admin":false,"second_factor_required":false,"security_key_required":false,"backup_enabled":false,"multiple_second_factor_methods":false}',
          )
        end

        expect(session["password-#{email_token.token}"]).to be_blank
        expect(UserAuthToken.where(id: user_auth_token.id).count).to eq(0)
      end

      it "disallows double password reset" do
        put "/u/password-reset/#{email_token.token}", params: { password: "hg9ow8yHG32O" }
        put "/u/password-reset/#{email_token.token}", params: { password: "test123987AsdfXYZ" }
        expect(user1.reload.confirm_password?("hg9ow8yHG32O")).to eq(true)
        expect(user1.user_auth_tokens.count).to eq(1)
      end

      it "doesn't redirect to wizard on get" do
        user1.update!(admin: true)

        get "/u/password-reset/#{email_token.token}.json"
        expect(response).not_to redirect_to(wizard_path)
      end

      it "redirects to the wizard if you're the first admin" do
        user1.update!(admin: true)

        get "/u/password-reset/#{email_token.token}"
        put "/u/password-reset/#{email_token.token}",
            params: {
              password: "hg9ow8yhg98oadminlonger",
            }
        expect(response).to redirect_to(wizard_path)
      end

      it "sets the users timezone if the param is present" do
        get "/u/password-reset/#{email_token.token}"
        expect(user1.user_option.timezone).to eq(nil)

        put "/u/password-reset/#{email_token.token}",
            params: {
              password: "hg9ow8yhg98oadminlonger",
              timezone: "America/Chicago",
            }
        expect(user1.user_option.reload.timezone).to eq("America/Chicago")
      end

      it "deletes user associated accounts" do
        SiteSetting.delete_associated_accounts_on_password_reset = true
        UserAssociatedAccount.create(
          user_id: user.id,
          provider_uid: "example0",
          provider_name: "facebook",
        )
        UserAssociatedAccount.create(
          user_id: user1.id,
          provider_uid: "example1",
          provider_name: "facebook",
        )

        get "/u/password-reset/#{email_token.token}"

        expect do
          put "/u/password-reset/#{email_token.token}",
              params: {
                password: "hg9ow8yhg98oadminlonger",
              }
        end.to change { UserAssociatedAccount.count }.by(-1)

        expect(UserAssociatedAccount.count).to eq(1)
      end

      it "logs the password change" do
        get "/u/password-reset/#{email_token.token}"

        expect do
          put "/u/password-reset/#{email_token.token}",
              params: {
                password: "hg9ow8yhg98oadminlonger",
              }
        end.to change { UserHistory.count }.by(1)

        user_history = UserHistory.last
        expect(user_history.target_user_id).to eq(user1.id)
        expect(user_history.action).to eq(UserHistory.actions[:change_password])
      end

      it "doesn't invalidate the token when loading the page" do
        get "/u/password-reset/#{email_token.token}.json"
        expect(response.status).to eq(200)
        expect(email_token.reload.confirmed).to eq(false)
        expect(UserAuthToken.where(id: user_auth_token.id).count).to eq(1)
      end

      context "with rate limiting" do
        before { RateLimiter.enable }

        it "rate limits reset passwords" do
          freeze_time

          6.times do
            put "/u/password-reset/#{email_token.token}",
                params: {
                  second_factor_token: 123_456,
                  second_factor_method: 1,
                }

            expect(response.status).to eq(200)
          end

          put "/u/password-reset/#{email_token.token}",
              params: {
                second_factor_token: 123_456,
                second_factor_method: 1,
              }

          expect(response.status).to eq(429)
        end

        it "rate limits reset passwords by username" do
          freeze_time

          6.times do |x|
            put "/u/password-reset/#{email_token.token}",
                params: {
                  second_factor_token: 123_456,
                  second_factor_method: 1,
                },
                env: {
                  REMOTE_ADDR: "1.2.3.#{x}",
                }

            expect(response.status).to eq(200)
          end

          put "/u/password-reset/#{email_token.token}",
              params: {
                second_factor_token: 123_456,
                second_factor_method: 1,
              },
              env: {
                REMOTE_ADDR: "1.2.3.4",
              }

          expect(response.status).to eq(429)
        end
      end

      context "when 2 factor authentication is required" do
        fab!(:second_factor) { Fabricate(:user_second_factor_totp, user: user1) }

        it "does not change with an invalid token" do
          user1.user_auth_tokens.destroy_all

          get "/u/password-reset/#{email_token.token}"

          expect(response.body).to have_tag("div#data-preloaded") do |element|
            json = JSON.parse(element.current_scope.attribute("data-preloaded").value)
            expect(json["password_reset"]).to include(
              '{"is_developer":false,"admin":false,"second_factor_required":true,"security_key_required":false,"backup_enabled":false,"multiple_second_factor_methods":false}',
            )
          end

          put "/u/password-reset/#{email_token.token}",
              params: {
                password: "hg9ow8yHG32O",
                second_factor_token: "000000",
                second_factor_method: UserSecondFactor.methods[:totp],
              }

          expect(response.body).to include(I18n.t("login.invalid_second_factor_code"))

          user1.reload
          expect(user1.confirm_password?("hg9ow8yHG32O")).not_to eq(true)
          expect(user1.user_auth_tokens.count).not_to eq(1)
        end

        it "changes password with valid 2-factor tokens" do
          get "/u/password-reset/#{email_token.token}"

          put "/u/password-reset/#{email_token.token}",
              params: {
                password: "hg9ow8yHG32O",
                second_factor_token: ROTP::TOTP.new(second_factor.data).now,
                second_factor_method: UserSecondFactor.methods[:totp],
              }

          user1.reload
          expect(response.status).to eq(200)
          expect(user1.confirm_password?("hg9ow8yHG32O")).to eq(true)
          expect(user1.user_auth_tokens.count).to eq(1)
        end
      end

      context "when security key authentication is required" do
        let!(:user_security_key) do
          Fabricate(
            :user_security_key,
            user: user1,
            credential_id: valid_security_key_data[:credential_id],
            public_key: valid_security_key_data[:public_key],
          )
        end

        before do
          simulate_localhost_webauthn_challenge
          DiscourseWebauthn.stubs(:origin).returns("http://localhost:3000")

          # store challenge in secure session by visiting the email login page
          get "/u/password-reset/#{email_token.token}"
        end

        it "preloads with a security key challenge and allowed credential ids" do
          expect(response.body).to have_tag("div#data-preloaded") do |element|
            json = JSON.parse(element.current_scope.attribute("data-preloaded").value)
            password_reset = JSON.parse(json["password_reset"])
            expect(password_reset["challenge"]).not_to eq(nil)
            expect(password_reset["allowed_credential_ids"]).to eq(
              [user_security_key.credential_id],
            )
            expect(password_reset["security_key_required"]).to eq(true)
          end
        end

        it "stages a webauthn challenge for the user" do
          secure_session = SecureSession.new(session["secure_session_id"])
          expect(DiscourseWebauthn.challenge(user1, secure_session)).not_to eq(nil)
        end

        it "changes password with valid security key challenge and authentication" do
          put "/u/password-reset/#{email_token.token}.json",
              params: {
                password: "hg9ow8yHG32O",
                second_factor_token: valid_security_key_auth_post_data,
                second_factor_method: UserSecondFactor.methods[:security_key],
              }

          expect(response.status).to eq(200)
          user1.reload
          expect(user1.confirm_password?("hg9ow8yHG32O")).to eq(true)
          expect(user1.user_auth_tokens.count).to eq(1)
        end

        it "does not change a password if a fake TOTP token is provided" do
          put "/u/password-reset/#{email_token.token}.json",
              params: {
                password: "hg9ow8yHG32O",
                second_factor_token: "blah",
                second_factor_method: UserSecondFactor.methods[:security_key],
              }

          expect(response.status).to eq(200)
          expect(user1.reload.confirm_password?("hg9ow8yHG32O")).to eq(false)
        end

        context "when security key authentication fails" do
          it "shows an error message and does not change password" do
            put "/u/password-reset/#{email_token.token}",
                params: {
                  password: "hg9ow8yHG32O",
                  second_factor_token: {
                    signature: "bad",
                    clientData: "bad",
                    authenticatorData: "bad",
                    credentialId: "bad",
                  },
                  second_factor_method: UserSecondFactor.methods[:security_key],
                }

            expect(response.status).to eq(200)
            expect(response.body).to include(I18n.t("webauthn.validation.not_found_error"))
            expect(user1.reload.confirm_password?("hg9ow8yHG32O")).to eq(false)
          end
        end
      end
    end

    context "with submit change" do
      let(:email_token) do
        Fabricate(:email_token, user: user1, scope: EmailToken.scopes[:password_reset])
      end

      it "fails when the password is blank" do
        put "/u/password-reset/#{email_token.token}.json", params: { password: "" }

        expect(response.status).to eq(200)
        expect(response.parsed_body["errors"]).to be_present
        expect(session[:current_user_id]).to be_blank
      end

      it "fails when the password is too long" do
        put "/u/password-reset/#{email_token.token}.json",
            params: {
              password: ("x" * (User.max_password_length + 1)),
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["errors"]).to be_present
        expect(session[:current_user_id]).to be_blank
      end

      it "logs in the user" do
        put "/u/password-reset/#{email_token.token}.json", params: { password: "ksjafh928r" }

        expect(response.status).to eq(200)
        expect(response.parsed_body["errors"]).to be_blank
        expect(session[:current_user_id]).to be_present
      end

      it "doesn't log in the user when not approved" do
        SiteSetting.must_approve_users = true
        user1.update!(approved: false)

        put "/u/password-reset/#{email_token.token}.json", params: { password: "ksjafh928r" }
        expect(response.parsed_body["errors"]).to be_blank
        expect(session[:current_user_id]).to be_blank
      end

      context "when in staff writes only mode" do
        before { Discourse.enable_readonly_mode(Discourse::STAFF_WRITES_ONLY_MODE_KEY) }

        it "allows staff to reset their password" do
          admin = Fabricate(:admin)
          email_token =
            Fabricate(:email_token, user: admin, scope: EmailToken.scopes[:password_reset])

          put "/u/password-reset/#{email_token.token}.json",
              params: {
                password: "hg9ow8yhg98oadminlonger",
              }

          expect(response.parsed_body["errors"]).to be_blank
          expect(session[:current_user_id]).to eq(admin.id)
        end

        it "doesn't allow non-staff to reset their password" do
          put "/u/password-reset/#{email_token.token}.json", params: { password: "ksjafh928r" }
          expect(response.parsed_body["errors"]).to_not be_blank
          expect(session[:current_user_id]).to be_blank
        end
      end
    end
  end

  describe "#confirm_email_token" do
    let!(:email_token) { Fabricate(:email_token, user: user1) }

    it "token doesn't match any records" do
      get "/u/confirm-email-token/#{SecureRandom.hex}.json"
      expect(response.status).to eq(200)
      expect(email_token.reload.confirmed).to eq(false)
    end

    it "token matches" do
      get "/u/confirm-email-token/#{email_token.token}.json"
      expect(response.status).to eq(200)
      expect(email_token.reload.confirmed).to eq(true)
    end
  end

  describe "#admin_login" do
    it "enqueues mail with admin email and sso enabled" do
      put "/u/admin-login", params: { email: admin.email }
      expect(response.status).to eq(200)
      expect(Jobs::CriticalUserEmail.jobs.size).to eq(1)
      args = Jobs::CriticalUserEmail.jobs.first["args"].first
      expect(args["user_id"]).to eq(admin.id)
    end

    it "passes through safe mode" do
      put "/u/admin-login", params: { email: admin.email, use_safe_mode: true }
      expect(response.status).to eq(200)
      expect(Jobs::CriticalUserEmail.jobs.size).to eq(1)
      args = Jobs::CriticalUserEmail.jobs.first["args"].first
      expect(args["email_token"]).to end_with("?safe_mode=no_plugins,no_themes")
    end

    context "when email is incorrect" do
      it "should return the right response" do
        put "/u/admin-login", params: { email: "random" }

        expect(response.status).to eq(200)

        response_body = response.body

        expect(response_body).to match(I18n.t("admin_login.errors.unknown_email_address"))
        expect(response_body).to_not match(I18n.t("login.second_factor_description"))
      end
    end
  end

  describe "#toggle_anon" do
    it "allows you to toggle anon if enabled" do
      SiteSetting.allow_anonymous_posting = true

      user = sign_in(Fabricate(:user, trust_level: TrustLevel[1]))

      post "/u/toggle-anon.json"
      expect(response.status).to eq(200)
      expect(session[:current_user_id]).to eq(AnonymousShadowCreator.get(user).id)

      post "/u/toggle-anon.json"
      expect(response.status).to eq(200)
      expect(session[:current_user_id]).to eq(user.id)
    end
  end

  describe "#create" do
    def honeypot_magic(params)
      get "/session/hp.json"
      json = response.parsed_body
      params[:password_confirmation] = json["value"]
      params[:challenge] = json["challenge"].reverse
      params
    end

    before do
      UsersController.any_instance.stubs(:honeypot_value).returns(nil)
      UsersController.any_instance.stubs(:challenge_value).returns(nil)
      SiteSetting.allow_new_registrations = true
      @user = Fabricate.build(:user, email: "foobar@example.com", password: "strongpassword")
    end

    let(:post_user_params) do
      { name: @user.name, username: @user.username, password: "strongpassword", email: @user.email }
    end

    def post_user(extra_params = {})
      post "/u.json", params: post_user_params.merge(extra_params)
    end

    context "when email params is missing" do
      it "should raise the right error" do
        post "/u.json",
             params: {
               name: @user.name,
               username: @user.username,
               password: "testing12352343",
             }
        expect(response.status).to eq(400)
      end
    end

    context "when using an encoded email that decodes to an invalid email" do
      it "blocks the registration" do
        post_user(email: "=?x?q?hacker=40hackerdomain.com=3e=00?=osama@discourseemail.com")
        expect(response.status).to eq(200)
        expect(response.parsed_body["success"]).to eq(false)
        expect(response.parsed_body["message"]).to eq("Primary email is invalid.")
        expect(response.parsed_body["user_id"]).to be_blank
      end
    end

    context "when using an encoded email that decodes to a valid email" do
      it "accepts the registration" do
        post_user(
          email:
            "=?utf-8?q?=6f=73=61=6d=61=2d=69=6e=2d=71=2d=65=6e=63=6f=64=69=6e=67?=@discourse.org",
        )
        expect(response.status).to eq(200)
        expect(response.parsed_body["success"]).to eq(true)
        expect(User.find_by(id: response.parsed_body["user_id"])).to be_present
      end
    end

    context "when creating a user" do
      it "sets the user locale to I18n.locale" do
        SiteSetting.default_locale = "en"
        I18n.stubs(:locale).returns(:fr)
        post_user
        expect(User.find_by(username: @user.username).locale).to eq("fr")
      end

      it "requires invite code when specified" do
        expect(SiteSetting.require_invite_code).to eq(false)
        SiteSetting.invite_code = "abc def"
        expect(SiteSetting.require_invite_code).to eq(true)

        post_user(invite_code: "abcd")
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["success"]).to eq(false)

        # case insensitive and stripped of leading/ending spaces
        post_user(invite_code: " AbC deF ")
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["success"]).to eq(true)
      end

      context "when timezone is provided as a guess on signup" do
        it "sets the timezone" do
          post_user(timezone: "Australia/Brisbane")
          expect(response.status).to eq(200)
          expect(User.find_by(username: @user.username).user_option.timezone).to eq(
            "Australia/Brisbane",
          )
        end
      end

      context "with local logins disabled" do
        before do
          SiteSetting.enable_local_logins = false
          SiteSetting.enable_google_oauth2_logins = true
        end

        it "blocks registration without authenticator information" do
          post_user
          expect(response.status).to eq(403)
        end

        it "blocks with a regular api key" do
          api_key = Fabricate(:api_key, user: user1)
          post "/u.json", params: post_user_params, headers: { HTTP_API_KEY: api_key.key }
          expect(response.status).to eq(403)
        end

        it "works with an admin api key" do
          api_key = Fabricate(:api_key, user: admin)
          post "/u.json", params: post_user_params, headers: { HTTP_API_KEY: api_key.key }
          expect(response.status).to eq(200)
        end
      end

      context "with external_ids" do
        fab!(:api_key, refind: false) { Fabricate(:api_key, user: admin) }

        let(:plugin_auth_provider) do
          authenticator_class =
            Class.new(Auth::ManagedAuthenticator) do
              def name
                "pluginauth"
              end

              def enabled?
                true
              end
            end

          provider = Auth::AuthProvider.new
          provider.authenticator = authenticator_class.new
          provider
        end

        before { DiscoursePluginRegistry.register_auth_provider(plugin_auth_provider) }

        after { DiscoursePluginRegistry.reset! }

        it "creates User record" do
          params = {
            username: "foobar",
            email: "test@example.com",
            external_ids: {
              "pluginauth" => "pluginauth_uid",
            },
          }

          expect {
            post "/u.json", params: params, headers: { HTTP_API_KEY: api_key.key }
          }.to change { UserAssociatedAccount.count }.by(1).and change { User.count }.by(1)

          expect(response.status).to eq(200)

          user = User.last
          user_associated_account = UserAssociatedAccount.last

          expect(user.username).to eq("foobar")
          expect(user.email).to eq("test@example.com")
          expect(user.user_associated_account_ids).to contain_exactly(user_associated_account.id)
          expect(user_associated_account.provider_name).to eq("pluginauth")
          expect(user_associated_account.provider_uid).to eq("pluginauth_uid")
          expect(user_associated_account.user_id).to eq(user.id)
        end

        it "returns error if external ID provider does not exist" do
          params = {
            username: "foobar",
            email: "test@example.com",
            external_ids: {
              "pluginauth2" => "pluginauth_uid",
            },
          }

          post "/u.json", params: params, headers: { HTTP_API_KEY: api_key.key }
          expect(response.status).to eq(400)
        end
      end
    end

    context "when creating a non active user (unconfirmed email)" do
      it "returns 403 forbidden when local logins are disabled" do
        SiteSetting.enable_local_logins = false
        post_user

        expect(response.status).to eq(403)
      end

      it "returns an error when new registrations are disabled" do
        SiteSetting.allow_new_registrations = false

        post_user
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["success"]).to eq(false)
        expect(json["message"]).to be_present
      end

      it "creates a user correctly" do
        post_user
        expect(response.status).to eq(200)
        expect(response.parsed_body["active"]).to be_falsey

        # should save user_created_message in session
        expect(session["user_created_message"]).to be_present
        expect(session[SessionController::ACTIVATE_USER_KEY]).to be_present

        expect(Jobs::SendSystemMessage.jobs.size).to eq(0)

        expect(Jobs::CriticalUserEmail.jobs.size).to eq(1)
        args = Jobs::CriticalUserEmail.jobs.first["args"].first
        expect(args["type"]).to eq("signup")
      end

      context "when `must approve users` site setting is enabled" do
        before { SiteSetting.must_approve_users = true }

        it "creates a user correctly" do
          post_user
          expect(response.status).to eq(200)

          expect(response.parsed_body["active"]).to be_falsey

          # should save user_created_message in session
          expect(session["user_created_message"]).to be_present
          expect(session[SessionController::ACTIVATE_USER_KEY]).to be_present

          expect(Jobs::SendSystemMessage.jobs.size).to eq(0)

          expect(Jobs::CriticalUserEmail.jobs.size).to eq(1)
          args = Jobs::CriticalUserEmail.jobs.first["args"].first
          expect(args["type"]).to eq("signup")
        end
      end

      context "when normalize_emails is enabled" do
        let(:email) { "jane+100@gmail.com" }
        let(:dupe_email) { "jane+191@gmail.com" }
        let!(:user) { Fabricate(:user, email: email, password: "strongpassword") }

        before do
          SiteSetting.hide_email_address_taken = true
          SiteSetting.normalize_emails = true
        end

        it "sends an email to normalized email owner when hide_email_address_taken is enabled" do
          expect do
            expect_enqueued_with(
              job: Jobs::CriticalUserEmail,
              args: {
                type: "account_exists",
                user_id: user.id,
              },
            ) do
              post "/u.json",
                   params: {
                     name: "Jane Doe",
                     username: "janedoe9999",
                     password: "strongpassword",
                     email: dupe_email,
                   }
            end
          end.to_not change { User.count }

          expect(response.status).to eq(200)
          expect(session["user_created_message"]).to be_present
        end
      end

      context "when users already exists with given email" do
        let!(:existing) { Fabricate(:user, email: post_user_params[:email]) }

        it "returns an error if hide_email_address_taken is disabled" do
          SiteSetting.hide_email_address_taken = false

          post_user
          expect(response.status).to eq(200)

          json = response.parsed_body
          expect(json["success"]).to eq(false)
          expect(json["message"]).to be_present
        end

        it "returns success if hide_email_address_taken is enabled" do
          SiteSetting.hide_email_address_taken = true
          expect {
            expect_enqueued_with(
              job: Jobs::CriticalUserEmail,
              args: {
                type: "account_exists",
                user_id: existing.id,
              },
            ) { post_user }
          }.to_not change { User.count }

          expect(response.status).to eq(200)
          expect(session["user_created_message"]).to be_present

          json = response.parsed_body
          expect(json["active"]).to be_falsey
          expect(json["message"]).to eq(
            I18n.t("login.activate_email", email: post_user_params[:email]),
          )
          expect(json["user_id"]).not_to be_present

          existing.destroy!
          expect { post_user }.to change { User.count }
          expect(response.status).to eq(200)
          json = response.parsed_body

          expect(json["active"]).to be_falsey
          expect(json["message"]).to eq(
            I18n.t("login.activate_email", email: post_user_params[:email]),
          )
          expect(json["user_id"]).not_to be_present
        end
      end
    end

    context "when creating as active" do
      it "won't create the user as active" do
        post "/u.json", params: post_user_params.merge(active: true)
        expect(response.status).to eq(200)
        expect(response.parsed_body["active"]).to be_falsey
      end

      context "with a regular api key" do
        fab!(:api_key, refind: false) { Fabricate(:api_key, user: user1) }

        it "won't create the user as active with a regular key" do
          post "/u.json",
               params: post_user_params.merge(active: true),
               headers: {
                 HTTP_API_KEY: api_key.key,
               }

          expect(response.status).to eq(200)
          expect(response.parsed_body["active"]).to be_falsey
        end
      end

      context "with an admin api key" do
        fab!(:api_key, refind: false) { Fabricate(:api_key, user: admin) }

        it "creates the user as active with a an admin key" do
          SiteSetting.send_welcome_message = true
          SiteSetting.must_approve_users = true

          # Sidekiq::Client.expects(:enqueue).never
          post "/u.json",
               params: post_user_params.merge(approved: true, active: true),
               headers: {
                 HTTP_API_KEY: api_key.key,
               }

          expect(Jobs::CriticalUserEmail.jobs.size).to eq(0)
          expect(Jobs::SendSystemMessage.jobs.size).to eq(0)

          expect(response.status).to eq(200)
          expect(response.parsed_body["active"]).to be_truthy
          new_user = User.find(response.parsed_body["user_id"])
          expect(new_user.active).to eq(true)
          expect(new_user.approved).to eq(true)
          expect(new_user.approved_by_id).to eq(admin.id)
          expect(new_user.approved_at).to_not eq(nil)
          expect(new_user.email_tokens.where(confirmed: true, email: new_user.email)).to exist
        end

        it "will create a reviewable when a user is created as active but not approved" do
          Jobs.run_immediately!
          SiteSetting.must_approve_users = true

          post "/u.json",
               params: post_user_params.merge(active: true),
               headers: {
                 HTTP_API_KEY: api_key.key,
               }

          expect(response.status).to eq(200)
          json = response.parsed_body

          new_user = User.find(json["user_id"])
          expect(json["active"]).to be_truthy
          expect(new_user.approved).to eq(false)
          expect(ReviewableUser.pending.find_by(target: new_user)).to be_present
        end

        it "won't create a reviewable when a user is not active" do
          Jobs.run_immediately!
          SiteSetting.must_approve_users = true

          post "/u.json", params: post_user_params, headers: { HTTP_API_KEY: api_key.key }

          expect(response.status).to eq(200)
          json = response.parsed_body

          new_user = User.find(json["user_id"])
          expect(json["active"]).to eq(false)
          expect(new_user.approved).to eq(false)
          expect(ReviewableUser.pending.find_by(target: new_user)).to be_blank
        end

        it "won't create the developer as active" do
          UsernameCheckerService.expects(:is_developer?).returns(true)

          post "/u.json",
               params: post_user_params.merge(active: true),
               headers: {
                 HTTP_API_KEY: api_key.key,
               }
          expect(response.status).to eq(200)
          expect(response.parsed_body["active"]).to be_falsy
        end

        it "won't set the new user's locale to the admin's locale" do
          SiteSetting.allow_user_locale = true
          admin.update!(locale: :fr)

          post "/u.json",
               params: post_user_params.merge(active: true),
               headers: {
                 HTTP_API_KEY: api_key.key,
               }
          expect(response.status).to eq(200)

          json = response.parsed_body
          new_user = User.find(json["user_id"])
          expect(new_user.locale).not_to eq("fr")
        end

        it "will auto approve user if the user email domain matches auto_approve_email_domains setting" do
          Jobs.run_immediately!
          SiteSetting.must_approve_users = true
          SiteSetting.auto_approve_email_domains = "example.com"

          post "/u.json",
               params: post_user_params.merge(active: true),
               headers: {
                 HTTP_API_KEY: api_key.key,
               }

          expect(response.status).to eq(200)
          json = response.parsed_body

          new_user = User.find(json["user_id"])
          expect(json["active"]).to be_truthy
          expect(new_user.approved).to be_truthy
          expect(ReviewableUser.pending.find_by(target: new_user)).to be_blank
        end
      end
    end

    context "when creating as staged" do
      it "won't create the user as staged" do
        post "/u.json", params: post_user_params.merge(staged: true)
        expect(response.status).to eq(200)
        new_user = User.where(username: post_user_params[:username]).first
        expect(new_user.staged?).to eq(false)
      end

      context "with a regular api key" do
        fab!(:api_key, refind: false) { Fabricate(:api_key, user: user1) }

        it "won't create the user as staged with a regular key" do
          post "/u.json",
               params: post_user_params.merge(staged: true),
               headers: {
                 HTTP_API_KEY: api_key.key,
               }
          expect(response.status).to eq(200)

          new_user = User.where(username: post_user_params[:username]).first
          expect(new_user.staged?).to eq(false)
        end
      end

      context "with an admin api key" do
        fab!(:user) { admin }
        fab!(:api_key, refind: false) { Fabricate(:api_key, user: user) }

        it "creates the user as staged with a regular key" do
          post "/u.json",
               params: post_user_params.merge(staged: true),
               headers: {
                 HTTP_API_KEY: api_key.key,
               }
          expect(response.status).to eq(200)

          new_user = User.where(username: post_user_params[:username]).first
          expect(new_user.staged?).to eq(true)
        end

        it "won't create the developer as staged" do
          UsernameCheckerService.expects(:is_developer?).returns(true)
          post "/u.json",
               params: post_user_params.merge(staged: true),
               headers: {
                 HTTP_API_KEY: api_key.key,
               }
          expect(response.status).to eq(200)

          new_user = User.where(username: post_user_params[:username]).first
          expect(new_user.staged?).to eq(false)
        end
      end
    end

    context "when creating an active user (confirmed email)" do
      before { User.any_instance.stubs(:active?).returns(true) }

      it "enqueues a welcome email" do
        User.any_instance.expects(:enqueue_welcome_message).with("welcome_user")

        post_user
        expect(response.status).to eq(200)

        # should save user_created_message in session
        expect(session["user_created_message"]).to be_present
        expect(session[SessionController::ACTIVATE_USER_KEY]).to be_present
      end

      it "shows the 'active' message" do
        User.any_instance.expects(:enqueue_welcome_message)
        post_user
        expect(response.status).to eq(200)
        expect(response.parsed_body["message"]).to eq(I18n.t "login.active")
      end

      it "should be logged in" do
        User.any_instance.expects(:enqueue_welcome_message)
        post_user
        expect(response.status).to eq(200)
        expect(session[:current_user_id]).to be_present
      end

      it "indicates the user is active in the response" do
        User.any_instance.expects(:enqueue_welcome_message)
        post_user
        expect(response.status).to eq(200)
        expect(response.parsed_body["active"]).to be_truthy
      end

      it 'doesn\'t succeed when new registrations are disabled' do
        SiteSetting.allow_new_registrations = false

        post_user
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["success"]).to eq(false)
        expect(json["message"]).to be_present
      end

      context "with authentication records for" do
        before do
          OmniAuth.config.test_mode = true

          OmniAuth.config.mock_auth[:twitter] = OmniAuth::AuthHash.new(
            provider: "twitter",
            uid: "123545",
            info:
              OmniAuth::AuthHash::InfoHash.new(
                email: "osama@mail.com",
                nickname: "testosama",
                name: "Osama Test",
              ),
          )

          Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:twitter]
          SiteSetting.enable_twitter_logins = true
          get "/auth/twitter/callback.json"
        end

        after do
          Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:twitter] = nil
          OmniAuth.config.test_mode = false
        end

        it "should create twitter user info if required" do
          post "/u.json",
               params: {
                 name: "Test Osama",
                 username: "testosama",
                 password: "strongpassword",
                 email: "osama@mail.com",
               }

          expect(response.status).to eq(200)
          expect(UserAssociatedAccount.where(provider_name: "twitter").count).to eq(1)
        end

        it "returns an error when email has been changed from the validated email address" do
          post "/u.json",
               params: {
                 name: "Test Osama",
                 username: "testosama",
                 password: "strongpassword",
                 email: "unvalidatedemail@mail.com",
               }

          expect(response.status).to eq(200)
          json = response.parsed_body
          expect(json["success"]).to eq(false)
          expect(json["message"]).to be_present
        end

        it "will create the user successfully if email validation is required" do
          post "/u.json",
               params: {
                 name: "Test Osama",
                 username: "testosama",
                 password: "strongpassword",
                 email: "osama@mail.com",
               }

          expect(response.status).to eq(200)
          json = response.parsed_body
          expect(json["success"]).to eq(true)
        end

        it "doesn't use provided username/name if sso_overrides is enabled" do
          SiteSetting.auth_overrides_username = true
          SiteSetting.auth_overrides_name = true
          post "/u.json",
               params: {
                 username: "attemptednewname",
                 name: "Attempt At New Name",
                 password: "strongpassword",
                 email: "osama@mail.com",
               }

          expect(response.status).to eq(200)
          json = response.parsed_body
          expect(json["success"]).to eq(true)

          user = User.last

          expect(user.username).to eq("testosama")
          expect(user.name).to eq("Osama Test")
        end
      end

      context "with no email in the auth payload" do
        before do
          OmniAuth.config.test_mode = true
          OmniAuth.config.mock_auth[:twitter] = OmniAuth::AuthHash.new(
            provider: "twitter",
            uid: "123545",
            info: OmniAuth::AuthHash::InfoHash.new(nickname: "testosama", name: "Osama Test"),
          )
          Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:twitter]
          SiteSetting.enable_twitter_logins = true
          get "/auth/twitter/callback.json"
        end

        after do
          Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:twitter] = nil
          OmniAuth.config.test_mode = false
        end

        it "will create the user successfully" do
          Rails.application.env_config["omniauth.auth"].info.email = nil

          post "/u.json",
               params: {
                 name: "Test Osama",
                 username: "testosama",
                 password: "strongpassword",
                 email: "osama@mail.com",
               }

          expect(response.status).to eq(200)
          json = response.parsed_body
          expect(json["success"]).to eq(true)
        end
      end
    end

    it "creates user successfully but doesn't activate the account" do
      post_user
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["success"]).to eq(true)
      expect(User.find_by(username: @user.username).active).to eq(false)
    end

    shared_examples "honeypot fails" do
      it "should not create a new user" do
        User.any_instance.expects(:enqueue_welcome_message).never

        expect { post "/u.json", params: create_params }.to_not change { User.count }

        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["success"]).to eq(true)

        # should not change the session
        expect(session["user_created_message"]).to be_blank
        expect(session[SessionController::ACTIVATE_USER_KEY]).to be_blank
      end
    end

    context "when honeypot value is wrong" do
      before { UsersController.any_instance.stubs(:honeypot_value).returns("abc") }
      let(:create_params) do
        {
          name: @user.name,
          username: @user.username,
          password: "strongpassword",
          email: @user.email,
          password_confirmation: "wrong",
        }
      end
      include_examples "honeypot fails"
    end

    context "when challenge answer is wrong" do
      before { UsersController.any_instance.stubs(:challenge_value).returns("abc") }
      let(:create_params) do
        {
          name: @user.name,
          username: @user.username,
          password: "strongpassword",
          email: @user.email,
          challenge: "abc",
        }
      end
      include_examples "honeypot fails"
    end

    context "when 'invite only' setting is enabled" do
      before { SiteSetting.invite_only = true }

      let(:create_params) do
        {
          name: @user.name,
          username: @user.username,
          password: "strongpassword",
          email: @user.email,
        }
      end

      include_examples "honeypot fails"
    end

    shared_examples "failed signup" do
      it "should not create a new User" do
        expect { post "/u.json", params: create_params }.to_not change { User.count }
        expect(response.status).to eq(200)
      end

      it "should report failed" do
        post "/u.json", params: create_params
        json = response.parsed_body
        expect(json["success"]).not_to eq(true)

        # should not change the session
        expect(session["user_created_message"]).to be_blank
        expect(session[SessionController::ACTIVATE_USER_KEY]).to be_blank
      end
    end

    context "when password is blank" do
      let(:create_params) do
        { name: @user.name, username: @user.username, password: "", email: @user.email }
      end
      include_examples "failed signup"
    end

    context "when password is too long" do
      let(:create_params) do
        {
          name: @user.name,
          username: @user.username,
          password: "x" * (User.max_password_length + 1),
          email: @user.email,
        }
      end
      include_examples "failed signup"
    end

    context "when password param is missing" do
      let(:create_params) { { name: @user.name, username: @user.username, email: @user.email } }
      include_examples "failed signup"
    end

    context "with a reserved username" do
      let(:create_params) do
        { name: @user.name, username: "Reserved", email: @user.email, password: "strongpassword" }
      end
      before { SiteSetting.reserved_usernames = "a|reserved|b" }
      include_examples "failed signup"
    end

    context "with a username that matches a user route" do
      let(:create_params) do
        {
          name: @user.name,
          username: "account-created",
          email: @user.email,
          password: "strongpassword",
        }
      end
      include_examples "failed signup"
    end

    context "with a missing username" do
      let(:create_params) { { name: @user.name, email: @user.email, password: "x" * 20 } }

      it "should not create a new User" do
        expect { post "/u.json", params: create_params }.to_not change { User.count }
        expect(response.status).to eq(400)
      end
    end

    context "when an Exception is raised" do
      before { User.any_instance.stubs(:save).raises(ActiveRecord::StatementInvalid.new("Oh no")) }

      let(:create_params) do
        {
          name: @user.name,
          username: @user.username,
          password: "strongpassword",
          email: @user.email,
        }
      end

      include_examples "failed signup"
    end

    context "with custom fields" do
      fab!(:user_field)
      fab!(:another_field) { Fabricate(:user_field) }
      fab!(:optional_field) { Fabricate(:user_field, requirement: "optional") }

      context "without a value for the fields" do
        let(:create_params) do
          { name: @user.name, password: "watwatwat", username: @user.username, email: @user.email }
        end
        include_examples "failed signup"
      end

      context "with values for the fields" do
        let(:update_user_url) { "/u/#{user1.username}.json" }
        let(:field_id) { user_field.id.to_s }

        before { sign_in(user1) }

        context "with multple select fields" do
          let(:valid_options) { %w[Axe Sword] }

          fab!(:user_field) do
            Fabricate(:user_field, field_type: "multiselect") do
              user_field_options do
                [
                  Fabricate(:user_field_option, value: "Axe"),
                  Fabricate(:user_field_option, value: "Sword"),
                ]
              end
            end
          end

          it "should allow single values and not just arrays" do
            expect do
              put update_user_url, params: { user_fields: { field_id => "Axe" } }
            end.to change { user1.reload.user_fields[field_id] }.from(nil).to("Axe")

            expect do
              put update_user_url, params: { user_fields: { field_id => %w[Axe Juice Sword] } }
            end.to change { user1.reload.user_fields[field_id] }.from("Axe").to(%w[Axe Sword])
          end

          it "shouldn't allow unregistered field values" do
            expect do
              put update_user_url, params: { user_fields: { field_id => %w[Juice] } }
            end.not_to change { user1.reload.user_fields[field_id] }
          end

          it "should filter valid values" do
            expect do
              put update_user_url, params: { user_fields: { field_id => %w[Axe Juice Sword] } }
            end.to change { user1.reload.user_fields[field_id] }.from(nil).to(valid_options)
          end

          it "allows registered field values" do
            expect do
              put update_user_url, params: { user_fields: { field_id => valid_options } }
            end.to change { user1.reload.user_fields[field_id] }.from(nil).to(valid_options)
          end

          it "value can't be nil or empty if the field is required" do
            put update_user_url, params: { user_fields: { field_id => valid_options } }

            user_field.for_all_users!

            expect do
              put update_user_url, params: { user_fields: { field_id => nil } }
            end.not_to change { user1.reload.user_fields[field_id] }

            expect do
              put update_user_url, params: { user_fields: { field_id => "" } }
            end.not_to change { user1.reload.user_fields[field_id] }
          end

          it "value is required only on sign-up" do
            user_field.on_signup!

            expect do
              put update_user_url, params: { user_fields: { field_id => "" } }
            end.to change { user1.reload.user_fields[field_id] }.from(nil).to("")

            put update_user_url, params: { user_fields: { field_id => valid_options } }

            expect do
              put update_user_url, params: { user_fields: { field_id => "" } }
            end.not_to change { user1.reload.user_fields[field_id] }
          end

          it "value can nil or empty if the field is not required" do
            put update_user_url, params: { user_fields: { field_id => valid_options } }

            user_field.optional!

            expect do
              put update_user_url, params: { user_fields: { field_id => nil } }
            end.to change { user1.reload.user_fields[field_id] }.from(valid_options).to(nil)

            expect do
              put update_user_url, params: { user_fields: { field_id => "" } }
            end.to change { user1.reload.user_fields[field_id] }.from(nil).to("")
          end
        end

        context "with dropdown fields" do
          let(:valid_options) { ["Black Mesa", "Fox Hound"] }

          fab!(:user_field) do
            Fabricate(:user_field, field_type: "dropdown") do
              user_field_options do
                [
                  Fabricate(:user_field_option, value: "Black Mesa"),
                  Fabricate(:user_field_option, value: "Fox Hound"),
                ]
              end
            end
          end

          it "shouldn't allow unregistered field values" do
            expect do
              put update_user_url, params: { user_fields: { field_id => "Umbrella Corporation" } }
            end.not_to change { user1.reload.user_fields[field_id] }
          end

          it "allows registered field values" do
            expect do
              put update_user_url, params: { user_fields: { field_id => valid_options.first } }
            end.to change { user1.reload.user_fields[field_id] }.from(nil).to(valid_options.first)
          end

          it "value can't be nil if the field is required" do
            put update_user_url, params: { user_fields: { field_id => valid_options.first } }

            user_field.for_all_users!

            expect do
              put update_user_url, params: { user_fields: { field_id => nil } }
            end.not_to change { user1.reload.user_fields[field_id] }
          end

          it "value can be set to nil if the field is not required" do
            put update_user_url, params: { user_fields: { field_id => valid_options.last } }

            user_field.optional!

            expect do
              put update_user_url, params: { user_fields: { field_id => nil } }
            end.to change { user1.reload.user_fields[field_id] }.from(valid_options.last).to(nil)
          end
        end

        let(:create_params) do
          {
            name: @user.name,
            password: "suChS3cuRi7y",
            username: @user.username,
            email: @user.email,
            user_fields: {
              user_field.id.to_s => "value1",
              another_field.id.to_s => "value2",
            },
          }
        end

        it "should succeed without the optional field" do
          post "/u.json", params: create_params
          expect(response.status).to eq(200)
          inserted = User.find_by_email(@user.email)
          expect(inserted).to be_present
          expect(inserted.custom_fields).to be_present
          expect(inserted.custom_fields["user_field_#{user_field.id}"]).to eq("value1")
          expect(inserted.custom_fields["user_field_#{another_field.id}"]).to eq("value2")
          expect(inserted.custom_fields["user_field_#{optional_field.id}"]).to be_blank
        end

        it "should succeed with the optional field" do
          create_params[:user_fields][optional_field.id.to_s] = "value3"
          post "/u.json", params: create_params.merge(create_params)
          expect(response.status).to eq(200)
          inserted = User.find_by_email(@user.email)
          expect(inserted).to be_present
          expect(inserted.custom_fields).to be_present
          expect(inserted.custom_fields["user_field_#{user_field.id}"]).to eq("value1")
          expect(inserted.custom_fields["user_field_#{another_field.id}"]).to eq("value2")
          expect(inserted.custom_fields["user_field_#{optional_field.id}"]).to eq("value3")
        end

        it "trims excessively long fields" do
          create_params[:user_fields][optional_field.id.to_s] = ("x" * 3000)
          post "/u.json", params: create_params.merge(create_params)
          expect(response.status).to eq(200)
          inserted = User.find_by_email(@user.email)

          val = inserted.custom_fields["user_field_#{optional_field.id}"]
          expect(val.length).to eq(UserField.max_length)
        end
      end
    end

    context "with only optional custom fields" do
      fab!(:user_field) { Fabricate(:user_field, requirement: "optional") }

      context "without values for the fields" do
        let(:create_params) do
          {
            name: @user.name,
            password: "suChS3cuRi7y",
            username: @user.username,
            email: @user.email,
          }
        end

        it "should succeed" do
          post "/u.json", params: create_params
          expect(response.status).to eq(200)
          inserted = User.find_by_email(@user.email)
          expect(inserted).to be_present
          expect(inserted.custom_fields).not_to be_present
          expect(inserted.custom_fields["user_field_#{user_field.id}"]).to be_blank
        end
      end
    end

    context "when taking over a staged account" do
      before do
        UsersController.any_instance.stubs(:honeypot_value).returns("abc")
        UsersController.any_instance.stubs(:challenge_value).returns("efg")
        SessionController.any_instance.stubs(:honeypot_value).returns("abc")
        SessionController.any_instance.stubs(:challenge_value).returns("efg")
      end

      fab!(:staged) { Fabricate(:staged, email: "staged@account.com", active: true) }

      it "succeeds" do
        post "/u.json",
             params:
               honeypot_magic(email: staged.email, username: "zogstrip", password: "P4ssw0rd$$")

        expect(response.status).to eq(200)
        result = response.parsed_body
        expect(result["success"]).to eq(true)

        created_user = User.find_by_email(staged.email)
        expect(created_user.staged).to eq(false)
        expect(created_user.active).to eq(false)
        expect(created_user.registration_ip_address).to be_present
        expect(!!created_user.custom_fields["from_staged"]).to eq(true)

        # do not allow emails changes please

        put "/u/update-activation-email.json", params: { email: "bob@bob.com" }

        created_user.reload
        expect(created_user.email).to eq("staged@account.com")
        expect(response.status).to eq(403)
      end

      it "works with custom fields" do
        tennis_field = Fabricate(:user_field, show_on_profile: true, name: "Favorite tennis player")

        post "/u.json",
             params:
               honeypot_magic(
                 email: staged.email,
                 username: "dude",
                 password: "P4ssw0rd$$",
                 user_fields: {
                   [tennis_field.id] => "Nadal",
                 },
               )

        expect(response.status).to eq(200)
        result = response.parsed_body
        expect(result["success"]).to eq(true)

        created_user = User.find_by_email(staged.email)
        expect(created_user.staged).to eq(false)
        expect(created_user.active).to eq(false)
        expect(created_user.registration_ip_address).to be_present
        expect(!!created_user.custom_fields["from_staged"]).to eq(true)

        expect(created_user.custom_fields["user_field_#{tennis_field.id}"]).to eq("Nadal")
      end
    end
  end

  describe "#username" do
    it "raises an error when not logged in" do
      put "/u/somename/preferences/username.json"
      expect(response.status).to eq(403)
    end

    context "while logged in" do
      let(:old_username) { "OrigUsername" }
      let(:new_username) { "#{old_username}1234" }
      fab!(:user) { Fabricate(:user, username: "OrigUsername", refresh_auto_groups: true) }

      before do
        user.username = old_username
        sign_in(user)
      end

      it "raises an error without a new_username param" do
        put "/u/#{user.username}/preferences/username.json", params: { username: user.username }
        expect(response.status).to eq(400)
        expect(user.reload.username).to eq(old_username)
      end

      it 'raises an error when you don\'t have permission to change the username' do
        Guardian.any_instance.expects(:can_edit_username?).with(user).returns(false)

        put "/u/#{user.username}/preferences/username.json", params: { new_username: new_username }

        expect(response).to be_forbidden
        expect(user.reload.username).to eq(old_username)
      end

      it "raises an error when change_username fails" do
        put "/u/#{user.username}/preferences/username.json", params: { new_username: "@" }

        expect(response.status).to eq(422)

        body = response.parsed_body

        expect(body["errors"].first).to include(
          I18n.t("user.username.short", count: User.username_length.begin),
        )

        expect(user.reload.username).to eq(old_username)
      end

      it "should succeed in normal circumstances" do
        put "/u/#{user.username}/preferences/username.json", params: { new_username: new_username }

        expect(response.status).to eq(200)
        expect(user.reload.username).to eq(new_username)
      end

      it "raises an error when the username clashes with an existing user route" do
        put "/u/#{user.username}/preferences/username.json",
            params: {
              new_username: "account-created",
            }

        body = response.parsed_body

        expect(body["errors"].first).to include(I18n.t("login.reserved_username"))
      end

      it "raises an error when the username is in the reserved list" do
        SiteSetting.reserved_usernames = "reserved"

        put "/u/#{user.username}/preferences/username.json", params: { new_username: "reserved" }
        body = response.parsed_body

        expect(body["errors"].first).to include(I18n.t("login.reserved_username"))
      end

      it "should fail if the user is old" do
        # Older than the change period and >1 post
        user.created_at = Time.now - (SiteSetting.username_change_period + 1).days
        PostCreator.new(
          user,
          title: "This is a test topic",
          raw: "This is a test this is a test",
        ).create

        put "/u/#{user.username}/preferences/username.json", params: { new_username: new_username }

        expect(response).to be_forbidden
        expect(user.reload.username).to eq(old_username)
      end

      it "should create a staff action log when a staff member changes the username" do
        acting_user = admin
        sign_in(acting_user)

        put "/u/#{user.username}/preferences/username.json", params: { new_username: new_username }

        expect(response.status).to eq(200)
        expect(
          UserHistory.where(
            action: UserHistory.actions[:change_username],
            target_user_id: user.id,
            acting_user_id: acting_user.id,
          ),
        ).to be_present
        expect(user.reload.username).to eq(new_username)
      end

      it "should return a JSON response with the updated username" do
        put "/u/#{user.username}/preferences/username.json", params: { new_username: new_username }

        expect(response.parsed_body["username"]).to eq(new_username)
      end

      it "should respond with proper error message if auth_overrides_username is enabled" do
        SiteSetting.discourse_connect_url = "http://someurl.com"
        SiteSetting.enable_discourse_connect = true
        SiteSetting.auth_overrides_username = true
        acting_user = admin
        sign_in(acting_user)

        put "/u/#{user.username}/preferences/username.json", params: { new_username: new_username }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"].first).to include(
          I18n.t("errors.messages.auth_overrides_username"),
        )
      end
    end
  end

  describe "#check_username" do
    it "raises an error without any parameters" do
      get "/u/check_username.json"
      expect(response.status).to eq(400)
    end

    shared_examples "when username is unavailable" do
      it "should return available as false in the JSON and return a suggested username" do
        expect(response.status).to eq(200)
        expect(response.parsed_body["available"]).to eq(false)
        expect(response.parsed_body["suggestion"]).to be_present
      end
    end

    shared_examples "when username is available" do
      it "should return available in the JSON" do
        expect(response.status).to eq(200)
        expect(response.parsed_body["available"]).to eq(true)
      end
    end

    it "returns nothing when given an email param but no username" do
      get "/u/check_username.json", params: { email: "dood@example.com" }
      expect(response.status).to eq(200)
    end

    context "when username is available" do
      before { get "/u/check_username.json", params: { username: "BruceWayne" } }
      include_examples "when username is available"
    end

    context "when username is unavailable" do
      before { get "/u/check_username.json", params: { username: user1.username } }
      include_examples "when username is unavailable"
    end

    shared_examples "checking an invalid username" do
      it "should not return an available key but should return an error message" do
        expect(response.status).to eq(200)
        expect(response.parsed_body["available"]).to eq(nil)
        expect(response.parsed_body["errors"]).to be_present
      end
    end

    context "when has invalid characters" do
      before { get "/u/check_username.json", params: { username: "bad username" } }
      include_examples "checking an invalid username"

      it "should return the invalid characters message" do
        expect(response.status).to eq(200)
        expect(response.parsed_body["errors"]).to include(I18n.t(:"user.username.characters"))
      end
    end

    context "when is too long" do
      before do
        get "/u/check_username.json",
            params: {
              username: SecureRandom.alphanumeric(SiteSetting.max_username_length.to_i + 1),
            }
      end
      include_examples "checking an invalid username"

      it 'should return the "too long" message' do
        expect(response.status).to eq(200)
        expect(response.parsed_body["errors"]).to include(
          I18n.t(:"user.username.long", count: SiteSetting.max_username_length),
        )
      end
    end

    describe "different case of existing username" do
      context "when it's my username" do
        fab!(:user) { Fabricate(:user, username: "hansolo") }
        before do
          sign_in(user)

          get "/u/check_username.json", params: { username: "HanSolo" }
        end
        include_examples "when username is available"
      end

      context "when it's someone else's username" do
        fab!(:user) { Fabricate(:user, username: "hansolo") }
        fab!(:someone_else) { Fabricate(:user) }
        before do
          sign_in(someone_else)

          get "/u/check_username.json", params: { username: "HanSolo" }
        end
        include_examples "when username is unavailable"
      end

      context "when an admin changing it for someone else" do
        fab!(:user) { Fabricate(:user, username: "hansolo") }
        before do
          sign_in(admin)

          get "/u/check_username.json", params: { username: "HanSolo", for_user_id: user.id }
        end
        include_examples "when username is available"
      end
    end
  end

  describe "#check_email" do
    it "returns success if hide_email_address_taken is true" do
      SiteSetting.hide_email_address_taken = true

      get "/u/check_email.json", params: { email: user1.email }
      expect(response.parsed_body["success"]).to be_present
    end

    it "returns success if email is empty" do
      get "/u/check_email.json"
      expect(response.parsed_body["success"]).to be_present
    end

    it "returns failure if email is not valid" do
      get "/u/check_email.json", params: { email: "invalid" }
      expect(response.parsed_body["failed"]).to be_present
    end

    it "returns failure if email exists" do
      get "/u/check_email.json", params: { email: user1.email }
      expect(response.parsed_body["failed"]).to be_present

      get "/u/check_email.json", params: { email: user1.email.upcase }
      expect(response.parsed_body["failed"]).to be_present
    end

    it "returns success if email does not exists" do
      get "/u/check_email.json", params: { email: "available@example.com" }
      expect(response.parsed_body["success"]).to be_present
    end

    it "return success if user email is taken by staged user" do
      get "/u/check_email.json", params: { email: Fabricate(:staged).email }
      expect(response.parsed_body["success"]).to be_present
    end
  end

  describe "#invited" do
    it "fails for anonymous users" do
      get "/u/#{user1.username}/invited.json", params: { username: user1.username }

      expect(response.status).to eq(403)
    end

    it "returns success" do
      user = Fabricate(:user, trust_level: TrustLevel[2])
      Fabricate(:invite, invited_by: user)

      sign_in(user)
      get "/u/#{user.username}/invited.json", params: { username: user.username }

      expect(response.status).to eq(200)
      expect(response.parsed_body["counts"]["pending"]).to eq(1)
      expect(response.parsed_body["counts"]["total"]).to eq(1)
    end

    it "filters by all if viewing self" do
      inviter = Fabricate(:user, trust_level: TrustLevel[2])
      sign_in(inviter)

      Fabricate(:invite, email: "billybob@example.com", invited_by: inviter)
      redeemed_invite = Fabricate(:invite, email: "jimtom@example.com", invited_by: inviter)
      Fabricate(:invited_user, invite: redeemed_invite, user: invitee)

      get "/u/#{inviter.username}/invited.json", params: { filter: "pending", search: "billybob" }
      expect(response.status).to eq(200)

      invites = response.parsed_body["invites"]
      expect(invites.size).to eq(1)
      expect(invites.first).to include("email" => "billybob@example.com")

      get "/u/#{inviter.username}/invited.json",
          params: {
            filter: "redeemed",
            search: invitee.username,
          }
      expect(response.status).to eq(200)

      invites = response.parsed_body["invites"]
      expect(invites.size).to eq(1)
      expect(invites[0]["user"]).to be_present
    end

    it "doesn't filter by email if another regular user" do
      inviter = Fabricate(:user, trust_level: TrustLevel[2])
      sign_in(Fabricate(:user, trust_level: TrustLevel[2]))

      Fabricate(:invite, email: "billybob@example.com", invited_by: inviter)
      redeemed_invite = Fabricate(:invite, email: "jimtom@example.com", invited_by: inviter)
      Fabricate(:invited_user, invite: redeemed_invite, user: invitee)

      get "/u/#{inviter.username}/invited.json", params: { filter: "pending", search: "billybob" }
      expect(response.status).to eq(200)

      invites = response.parsed_body["invites"]
      expect(invites.size).to eq(0)

      get "/u/#{inviter.username}/invited.json",
          params: {
            filter: "redeemed",
            search: invitee.username,
          }
      expect(response.status).to eq(200)

      invites = response.parsed_body["invites"]
      expect(invites.size).to eq(1)
      expect(invites[0]["user"]).to be_present
    end

    it "filters by email if staff" do
      inviter = Fabricate(:user, trust_level: 2)
      sign_in(moderator)

      invite_1 = Fabricate(:invite, email: "billybob@example.com", invited_by: inviter)
      invitee_1 = Fabricate(:user)
      Fabricate(:invited_user, invite: invite_1, user: invitee_1)
      invite_2 = Fabricate(:invite, email: "jimtom@example.com", invited_by: inviter)
      invitee_2 = Fabricate(:user)
      Fabricate(:invited_user, invite: invite_2, user: invitee_2)

      get "/u/#{inviter.username}/invited.json", params: { search: "billybob" }
      expect(response.status).to eq(200)

      invites = response.parsed_body["invites"]
      expect(invites.size).to eq(1)
      expect(invites[0]["user"]).to include("id" => invitee_1.id)
    end

    context "with guest" do
      context "with pending invites" do
        it "does not return invites" do
          Fabricate(:invite, invited_by: inviter)

          get "/u/#{user1.username}/invited/pending.json"
          expect(response.status).to eq(403)
        end
      end

      context "with redeemed invites" do
        it "returns invited_users" do
          inviter = Fabricate(:user, trust_level: TrustLevel[2])
          sign_in(inviter)
          invite = Fabricate(:invite, invited_by: inviter)
          _invited_user = Fabricate(:invited_user, invite: invite, user: invitee)

          get "/u/#{inviter.username}/invited.json"
          expect(response.status).to eq(200)

          invites = response.parsed_body["invites"]
          expect(invites.size).to eq(1)
          expect(invites[0]).to include("id" => invite.id)
        end
      end
    end

    context "with authenticated user" do
      context "with pending invites" do
        context "with permission to see pending invites" do
          it "returns invites" do
            inviter = Fabricate(:user, trust_level: TrustLevel[2])
            invite = Fabricate(:invite, invited_by: inviter)
            sign_in(inviter)

            get "/u/#{inviter.username}/invited/pending.json"
            expect(response.status).to eq(200)

            invites = response.parsed_body["invites"]
            expect(invites.size).to eq(1)
            expect(invites.first).to include("email" => invite.email)
            expect(response.parsed_body["can_see_invite_details"]).to eq(true)
          end
        end

        context "without permission to see pending invites" do
          it "does not return invites" do
            user = sign_in(Fabricate(:user))
            Fabricate(:invite, invited_by: inviter)
            stub_guardian(user) do |guardian|
              guardian.stubs(:can_see_invite_details?).with(inviter).returns(false)
            end

            get "/u/#{inviter.username}/invited/pending.json"
            expect(response.status).to eq(422)
          end
        end

        context "with permission to see invite links" do
          it "returns own invites" do
            inviter = sign_in(Fabricate(:user, trust_level: TrustLevel[2]))
            invite =
              Fabricate(
                :invite,
                invited_by: inviter,
                email: nil,
                max_redemptions_allowed: 5,
                expires_at: 1.month.from_now,
                emailed_status: Invite.emailed_status_types[:not_required],
              )

            get "/u/#{inviter.username}/invited/pending.json"
            expect(response.status).to eq(200)

            invites = response.parsed_body["invites"]
            expect(invites.size).to eq(1)
            expect(invites.first).to include("id" => invite.id)
            expect(response.parsed_body["can_see_invite_details"]).to eq(true)
          end

          it "allows admin to see invites" do
            inviter = Fabricate(:user, trust_level: 2)
            _admin = sign_in(Fabricate(:admin))
            invite =
              Fabricate(
                :invite,
                invited_by: inviter,
                email: nil,
                max_redemptions_allowed: 5,
                expires_at: 1.month.from_now,
                emailed_status: Invite.emailed_status_types[:not_required],
              )

            get "/u/#{inviter.username}/invited/pending.json"
            expect(response.status).to eq(200)

            invites = response.parsed_body["invites"]
            expect(invites.size).to eq(1)
            expect(invites.first).to include("id" => invite.id)
            expect(response.parsed_body["can_see_invite_details"]).to eq(true)
          end
        end

        context "without permission to see invite links" do
          it "does not return invites" do
            _user = Fabricate(:user, trust_level: 2)
            inviter = admin
            Fabricate(
              :invite,
              invited_by: inviter,
              email: nil,
              max_redemptions_allowed: 5,
              expires_at: 1.month.from_now,
              emailed_status: Invite.emailed_status_types[:not_required],
            )

            get "/u/#{inviter.username}/invited/pending.json"
            expect(response.status).to eq(403)
          end
        end
      end

      context "with redeemed invites" do
        it "returns invites" do
          sign_in(moderator)
          invite = Fabricate(:invite, invited_by: inviter)
          Fabricate(:invited_user, invite: invite, user: invitee)

          get "/u/#{inviter.username}/invited.json"
          expect(response.status).to eq(200)

          invites = response.parsed_body["invites"]
          expect(invites.size).to eq(1)
          expect(invites[0]).to include("id" => invite.id)
        end
      end
    end
  end

  describe "#update" do
    context "with guest" do
      it "raises an error" do
        put "/u/guest.json"
        expect(response.status).to eq(403)
      end
    end

    it "does not allow name to be updated if auth auth_overrides_name is enabled" do
      SiteSetting.auth_overrides_name = true

      sign_in(user1)

      put "/u/#{user1.username}", params: { name: "test.test" }

      expect(response.status).to eq(200)
      expect(user1.reload.name).to_not eq("test.test")
    end

    context "when username contains a period" do
      before { sign_in(user) }

      fab!(:user) { Fabricate(:user, username: "test.test", name: "Test User") }

      it "should be able to update a user" do
        put "/u/#{user.username}", params: { name: "test.test" }

        expect(response.status).to eq(200)
        expect(user.reload.name).to eq("test.test")
      end
    end

    context "as a staff user" do
      context "with uneditable field" do
        fab!(:user_field) { Fabricate(:user_field, editable: false) }

        it "allows staff to edit the field" do
          sign_in(admin)
          put "/u/#{user.username}.json",
              params: {
                name: "Jim Tom",
                title: "foobar",
                user_fields: {
                  user_field.id.to_s => "happy",
                },
              }

          expect(response.status).to eq(200)

          user.reload

          expect(user.user_fields[user_field.id.to_s]).to eq("happy")
          expect(user.title).to eq("foobar")
        end
      end
    end

    context "with authenticated user" do
      context "with permission to update" do
        fab!(:upload)
        fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

        before do
          User.set_callback(:create, :after, :ensure_in_trust_level_group)
          sign_in(user)
        end

        after { User.skip_callback(:create, :after, :ensure_in_trust_level_group) }

        it "allows the update" do
          SiteSetting.tagging_enabled = true
          user2 = Fabricate(:user)
          user3 = Fabricate(:user)
          tags = [Fabricate(:tag), Fabricate(:tag)]
          tag_synonym = Fabricate(:tag, target_tag: tags[1])

          put "/u/#{user.username}.json",
              params: {
                name: "Jim Tom",
                muted_usernames: "#{user2.username},#{user3.username}",
                watched_tags: "#{tags[0].name},#{tag_synonym.name}",
                card_background_upload_url: upload.url,
                profile_background_upload_url: upload.url,
              }

          expect(response.status).to eq(200)
          expect(response.parsed_body["user"]["watched_tags"].count).to eq(2)

          user.reload

          expect(user.name).to eq "Jim Tom"
          expect(user.muted_users.pluck(:username).sort).to eq [user2.username, user3.username].sort

          expect(
            TagUser.where(
              user: user,
              notification_level: TagUser.notification_levels[:watching],
            ).pluck(:tag_id),
          ).to contain_exactly(tags[0].id, tags[1].id)

          theme = Fabricate(:theme, user_selectable: true)

          put "/u/#{user.username}.json",
              params: {
                muted_usernames: "",
                theme_ids: [theme.id],
                email_level: UserOption.email_level_types[:always],
              }

          user.reload

          expect(user.muted_users.pluck(:username).sort).to be_empty
          expect(user.user_option.theme_ids).to eq([theme.id])
          expect(user.user_option.email_level).to eq(UserOption.email_level_types[:always])
          expect(user.profile_background_upload).to eq(upload)
          expect(user.card_background_upload).to eq(upload)
        end

        it "does not allow updating attributes specific to user creation" do
          put "/u/#{user.username}.json",
              params: {
                username: "jimtom2",
                email: "newemail@example.com",
                password: "123456789",
              }

          expect(response.status).to eq(200)

          user.reload

          expect(user.username).not_to eq "jimtop2"
          expect(user.password).not_to eq "123456789"
          expect(user.email).not_to eq "newemail@example.com"
        end

        it "updates watched tags in everyone tag group" do
          SiteSetting.tagging_enabled = true
          tags = [Fabricate(:tag), Fabricate(:tag)]
          group =
            Fabricate(:group, name: "group", mentionable_level: Group::ALIAS_LEVELS[:everyone])
          tag_group = Fabricate(:tag_group, tags: tags)
          Fabricate(:tag_group_permission, tag_group: tag_group, group: group)
          tag_synonym = Fabricate(:tag, target_tag: tags[1])

          put "/u/#{user.username}.json",
              params: {
                watched_tags: "#{tags[0].name},#{tag_synonym.name}",
              }

          expect(response.status).to eq(200)
          expect(response.parsed_body["user"]["watched_tags"].count).to eq(2)
        end

        context "when a locale is chosen that differs from I18n.locale" do
          before { SiteSetting.allow_user_locale = true }

          it "updates the user's locale" do
            I18n.locale = :fr
            put "/u/#{user.username}.json", params: { locale: :fa_IR }
            expect(user.reload.locale).to eq("fa_IR")
          end

          it "updates the title" do
            BadgeGranter.enable_queue
            user.update!(locale: :fr)
            user.change_trust_level!(TrustLevel[4])
            BadgeGranter.process_queue!

            leader_title = I18n.t("badges.leader.name", locale: :fr)
            put "/u/#{user.username}.json", params: { title: leader_title }
            expect(user.reload.title).to eq(leader_title)
          ensure
            BadgeGranter.disable_queue
            BadgeGranter.clear_queue!
          end
        end

        context "with user fields" do
          context "with an editable field" do
            fab!(:user_field) { Fabricate(:user_field, requirement: "for_all_users") }
            fab!(:optional_field) { Fabricate(:user_field, requirement: "optional") }

            it "should update the user field" do
              put "/u/#{user.username}.json",
                  params: {
                    name: "Jim Tom",
                    user_fields: {
                      user_field.id.to_s => "happy",
                    },
                  }

              expect(response.status).to eq(200)
              expect(user.user_fields[user_field.id.to_s]).to eq "happy"
            end

            it "cannot be updated to blank" do
              put "/u/#{user.username}.json",
                  params: {
                    name: "Jim Tom",
                    user_fields: {
                      user_field.id.to_s => "",
                    },
                  }

              expect(response.status).to eq(422)
              expect(user.user_fields[user_field.id.to_s]).not_to eq("happy")
            end

            it "trims excessively large fields" do
              put "/u/#{user.username}.json",
                  params: {
                    name: "Jim Tom",
                    user_fields: {
                      user_field.id.to_s => ("x" * 3000),
                    },
                  }

              expect(user.user_fields[user_field.id.to_s].size).to eq(UserField.max_length)
            end

            it "should retain existing user fields" do
              put "/u/#{user.username}.json",
                  params: {
                    name: "Jim Tom",
                    user_fields: {
                      user_field.id.to_s => "happy",
                      optional_field.id.to_s => "feet",
                    },
                  }

              expect(response.status).to eq(200)
              expect(user.user_fields[user_field.id.to_s]).to eq("happy")
              expect(user.user_fields[optional_field.id.to_s]).to eq("feet")

              put "/u/#{user.username}.json",
                  params: {
                    name: "Jim Tom",
                    user_fields: {
                      user_field.id.to_s => "sad",
                    },
                  }

              expect(response.status).to eq(200)

              user.reload

              expect(user.user_fields[user_field.id.to_s]).to eq("sad")
              expect(user.user_fields[optional_field.id.to_s]).to eq("feet")
            end
          end

          context "with user_notification_schedule attributes" do
            it "updates the user's notification schedule" do
              params = {
                user_notification_schedule: {
                  enabled: true,
                  day_0_start_time: 30,
                  day_0_end_time: 60,
                  day_1_start_time: 30,
                  day_1_end_time: 60,
                  day_2_start_time: 30,
                  day_2_end_time: 60,
                  day_3_start_time: 30,
                  day_3_end_time: 60,
                  day_4_start_time: 30,
                  day_4_end_time: 60,
                  day_5_start_time: 30,
                  day_5_end_time: 60,
                  day_6_start_time: 30,
                  day_6_end_time: 60,
                },
              }
              put "/u/#{user.username}.json", params: params

              user.reload
              expect(user.user_notification_schedule.enabled).to eq(true)
              expect(user.user_notification_schedule.day_0_start_time).to eq(30)
              expect(user.user_notification_schedule.day_0_end_time).to eq(60)
              expect(user.user_notification_schedule.day_6_start_time).to eq(30)
              expect(user.user_notification_schedule.day_6_end_time).to eq(60)
            end
          end

          context "with uneditable field" do
            fab!(:user_field) { Fabricate(:user_field, editable: false) }

            it "does not update the user field" do
              put "/u/#{user.username}.json",
                  params: {
                    name: "Jim Tom",
                    user_fields: {
                      user_field.id.to_s => "happy",
                    },
                  }

              expect(response.status).to eq(200)
              expect(user.user_fields[user_field.id.to_s]).to be_blank
            end
          end

          context "with custom_field" do
            before do
              plugin = Plugin::Instance.new
              plugin.register_editable_user_custom_field :test2
              plugin.register_editable_user_custom_field :test3, staff_only: true
            end

            after { DiscoursePluginRegistry.reset! }

            it "only updates allowed user fields" do
              put "/u/#{user.username}.json",
                  params: {
                    custom_fields: {
                      test1: :hello1,
                      test2: :hello2,
                      test3: :hello3,
                    },
                  }

              expect(response.status).to eq(200)
              expect(user.custom_fields["test1"]).to be_blank
              expect(user.custom_fields["test2"]).to eq("hello2")
              expect(user.custom_fields["test3"]).to be_blank
            end

            it "works alongside a user field" do
              user_field = Fabricate(:user_field, editable: true)
              put "/u/#{user.username}.json",
                  params: {
                    custom_fields: {
                      test1: :hello1,
                      test2: :hello2,
                      test3: :hello3,
                    },
                    user_fields: {
                      user_field.id.to_s => "happy",
                    },
                  }
              expect(response.status).to eq(200)
              expect(user.custom_fields["test1"]).to be_blank
              expect(user.custom_fields["test2"]).to eq("hello2")
              expect(user.custom_fields["test3"]).to eq(nil)
              expect(user.user_fields[user_field.id.to_s]).to eq("happy")
            end

            it "works alongside a user field during creation" do
              api_key = Fabricate(:api_key, user: admin)
              user_field = Fabricate(:user_field, editable: true)
              post "/u.json",
                   params: {
                     name: "Test User",
                     username: "testuser",
                     email: "user@mail.com",
                     password: "supersecure",
                     active: true,
                     custom_fields: {
                       test2: "custom field value",
                     },
                     user_fields: {
                       user_field.id.to_s => "user field value",
                     },
                   },
                   headers: {
                     HTTP_API_KEY: api_key.key,
                   }
              expect(response.status).to eq(200)
              u = User.find_by_email("user@mail.com")

              val = u.custom_fields["user_field_#{user_field.id}"]
              expect(val).to eq("user field value")

              val = u.custom_fields["test2"]
              expect(val).to eq("custom field value")
            end

            it "is secure when there are no registered editable fields" do
              DiscoursePluginRegistry.reset!
              put "/u/#{user.username}.json",
                  params: {
                    custom_fields: {
                      test1: :hello1,
                      test2: :hello2,
                      test3: :hello3,
                    },
                  }
              expect(response.status).to eq(200)
              expect(user.custom_fields["test1"]).to be_blank
              expect(user.custom_fields["test2"]).to be_blank
              expect(user.custom_fields["test3"]).to be_blank

              put "/u/#{user.username}.json", params: { custom_fields: %w[arrayitem1 arrayitem2] }
              expect(response.status).to eq(200)
            end

            it "allows staff to edit staff-editable fields" do
              sign_in(admin)
              put "/u/#{user.username}.json",
                  params: {
                    custom_fields: {
                      test1: :hello1,
                      test2: :hello2,
                      test3: :hello3,
                    },
                  }

              expect(response.status).to eq(200)
              expect(user.custom_fields["test1"]).to be_blank
              expect(user.custom_fields["test2"]).to eq("hello2")
              expect(user.custom_fields["test3"]).to eq("hello3")
            end
          end
        end

        it "returns user JSON" do
          put "/u/#{user.username}.json"

          json = response.parsed_body
          expect(json["user"]["id"]).to eq user.id
        end

        context "with sidebar" do
          before { SiteSetting.navigation_menu = "sidebar" }

          it "does not remove category or tag sidebar section links when params are not present" do
            Fabricate(:category_sidebar_section_link, user: user)
            Fabricate(:tag_sidebar_section_link, user: user)

            expect do
              put "/u/#{user.username}.json"

              expect(response.status).to eq(200)
            end.to_not change { user.sidebar_section_links.count }
          end

          it "should allow user to remove all category sidebar section links" do
            Fabricate(:category_sidebar_section_link, user: user)

            expect do
              put "/u/#{user.username}.json", params: { sidebar_category_ids: nil }

              expect(response.status).to eq(200)
            end.to change { user.sidebar_section_links.count }.from(1).to(0)
          end

          it "should allow user to only modify category sidebar section links for categories they have access to" do
            category = Fabricate(:category)
            group = Fabricate(:group)
            restricted_category = Fabricate(:private_category, group: group)
            category_sidebar_section_link = Fabricate(:category_sidebar_section_link, user: user)

            put "/u/#{user.username}.json",
                params: {
                  sidebar_category_ids: [category.id, restricted_category.id],
                }

            expect(response.status).to eq(200)
            expect(user.sidebar_section_links.count).to eq(1)
            expect(SidebarSectionLink.exists?(id: category_sidebar_section_link.id)).to eq(false)

            sidebar_section_link = user.sidebar_section_links.first

            expect(sidebar_section_link.linkable).to eq(category)

            group.add(user)

            expect do
              put "/u/#{user.username}.json",
                  params: {
                    sidebar_category_ids: [category.id, restricted_category.id],
                  }

              expect(response.status).to eq(200)
            end.to change { user.sidebar_section_links.count }.from(1).to(2)

            expect(SidebarSectionLink.exists?(user: user, linkable: restricted_category)).to eq(
              true,
            )
          end

          it "should allow user to remove all tag sidebar section links" do
            SiteSetting.tagging_enabled = true

            Fabricate(:tag_sidebar_section_link, user: user)

            expect do
              put "/u/#{user.username}.json", params: { sidebar_tag_names: nil }

              expect(response.status).to eq(200)
            end.to change { user.sidebar_section_links.count }.from(1).to(0)
          end

          it "should not allow user to add tag sidebar section links when tagging is disabled" do
            SiteSetting.tagging_enabled = false

            tag = Fabricate(:tag)

            put "/u/#{user.username}.json", params: { sidebar_tag_names: [tag.name] }

            expect(response.status).to eq(200)
            expect(user.reload.sidebar_section_links.count).to eq(0)
          end

          it "should allow user to add tag sidebar section links only for tags that are visible to the user" do
            SiteSetting.tagging_enabled = true

            tag = Fabricate(:tag)
            tag_sidebar_section_link = Fabricate(:tag_sidebar_section_link, user: user)

            hidden_tag = Fabricate(:tag)
            Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])

            put "/u/#{user.username}.json",
                params: {
                  sidebar_tag_names: [tag.name, "somerandomtag", hidden_tag.name],
                }

            expect(response.status).to eq(200)
            expect(user.sidebar_section_links.count).to eq(1)
            expect(SidebarSectionLink.exists?(id: tag_sidebar_section_link.id)).to eq(false)

            sidebar_section_link = user.sidebar_section_links.first

            expect(sidebar_section_link.linkable).to eq(tag)

            user.update!(admin: true)

            expect do
              put "/u/#{user.username}.json",
                  params: {
                    sidebar_tag_names: [tag.name, "somerandomtag", hidden_tag.name],
                  }

              expect(response.status).to eq(200)
            end.to change { user.sidebar_section_links.count }.from(1).to(2)

            expect(SidebarSectionLink.exists?(user: user, linkable: hidden_tag)).to eq(true)
          end
        end
      end

      context "without permission to update" do
        it "does not allow the update" do
          user = Fabricate(:user, name: "Billy Bob")
          sign_in(Fabricate(:user))

          put "/u/#{user.username}.json", params: { name: "Jim Tom" }

          expect(response).to be_forbidden
          expect(user.reload.name).not_to eq "Jim Tom"
        end
      end
    end

    context "with external_ids" do
      fab!(:api_key, refind: false) { Fabricate(:api_key, user: admin) }

      let(:plugin_auth_provider) do
        authenticator_class =
          Class.new(Auth::ManagedAuthenticator) do
            def name
              "pluginauth"
            end

            def enabled?
              true
            end
          end

        provider = Auth::AuthProvider.new
        provider.authenticator = authenticator_class.new
        provider
      end

      before do
        DiscoursePluginRegistry.register_auth_provider(plugin_auth_provider)
        SiteSetting.discourse_connect_url = "http://localhost"
        SiteSetting.enable_discourse_connect = true
      end

      after { DiscoursePluginRegistry.reset! }

      it "can create UserAssociatedAccount records" do
        params = { external_ids: { "pluginauth" => "pluginauth_uid" } }

        expect {
          put "/u/#{user.username}.json", params: params, headers: { HTTP_API_KEY: api_key.key }
        }.to change { UserAssociatedAccount.count }.by(1)

        expect(response.status).to eq(200)

        user_associated_account = UserAssociatedAccount.last
        expect(user.reload.user_associated_account_ids).to contain_exactly(
          user_associated_account.id,
        )
        expect(user_associated_account.provider_name).to eq("pluginauth")
        expect(user_associated_account.provider_uid).to eq("pluginauth_uid")
        expect(user_associated_account.user_id).to eq(user.id)
      end

      it "can destroy UserAssociatedAccount records" do
        user.user_associated_accounts.create!(
          provider_name: "pluginauth",
          provider_uid: "pluginauth_uid",
        )

        params = { external_ids: { "pluginauth" => nil } }

        expect {
          put "/u/#{user.username}.json", params: params, headers: { HTTP_API_KEY: api_key.key }
        }.to change { UserAssociatedAccount.count }.by(-1)

        expect(response.status).to eq(200)
        expect(user.reload.user_associated_account_ids).to be_blank
      end

      it "can create SingleSignOnRecord records" do
        params = { external_ids: { discourse_connect: "discourse_connect_uid" } }

        expect {
          put "/u/#{user.username}.json", params: params, headers: { HTTP_API_KEY: api_key.key }
        }.to change { SingleSignOnRecord.count }.by(1)

        expect(response.status).to eq(200)

        single_sign_on_record = SingleSignOnRecord.last
        expect(user.reload.single_sign_on_record).to eq(single_sign_on_record)
        expect(single_sign_on_record.external_id).to eq("discourse_connect_uid")
      end

      it "can update SingleSignOnRecord records" do
        user = Fabricate(:user)
        SingleSignOnRecord.create!(
          user_id: user.id,
          external_id: "discourse_connect_uid",
          last_payload: "discourse_connect_uid",
        )

        params = { external_ids: { discourse_connect: "discourse_connect_uid_2" } }

        expect {
          put "/u/#{user.username}.json", params: params, headers: { HTTP_API_KEY: api_key.key }
        }.not_to change { SingleSignOnRecord.count }

        expect(response.status).to eq(200)
        expect(user.reload.single_sign_on_record.external_id).to eq("discourse_connect_uid_2")
      end

      it "can delete SingleSignOnRecord records" do
        user = Fabricate(:user)
        SingleSignOnRecord.create!(
          user_id: user.id,
          external_id: "discourse_connect_uid",
          last_payload: "discourse_connect_uid",
        )

        params = { external_ids: { discourse_connect: nil } }

        expect {
          put "/u/#{user.username}.json", params: params, headers: { HTTP_API_KEY: api_key.key }
        }.to change { SingleSignOnRecord.count }.by(-1)

        expect(response.status).to eq(200)
        expect(user.reload.single_sign_on_record).to be_blank
      end

      it "can update SingleSignOnRecord and UserAssociatedAccount records in a single call" do
        user = Fabricate(:user)
        user.user_associated_accounts.create!(
          provider_name: "pluginauth",
          provider_uid: "pluginauth_uid",
        )
        SingleSignOnRecord.create!(
          user_id: user.id,
          external_id: "discourse_connect_uid",
          last_payload: "discourse_connect_uid",
        )

        params = {
          external_ids: {
            discourse_connect: "discourse_connect_uid_2",
            pluginauth: "pluginauth_uid_2",
          },
        }

        expect {
          put "/u/#{user.username}.json", params: params, headers: { HTTP_API_KEY: api_key.key }
        }.to change { SingleSignOnRecord.count + UserAssociatedAccount.count }.by(0)

        expect(response.status).to eq(200)
        expect(user.reload.single_sign_on_record.external_id).to eq("discourse_connect_uid_2")
        user_associated_account = UserAssociatedAccount.last
        expect(user.reload.user_associated_account_ids).to contain_exactly(
          user_associated_account.id,
        )
        expect(user_associated_account.provider_name).to eq("pluginauth")
        expect(user_associated_account.provider_uid).to eq("pluginauth_uid_2")
        expect(user_associated_account.user_id).to eq(user.id)
      end

      it "returns error if external ID provider does not exist" do
        params = { external_ids: { "pluginauth2" => "pluginauth_uid" } }

        put "/u/#{user.username}.json", params: params, headers: { HTTP_API_KEY: api_key.key }
        expect(response.status).to eq(400)
      end
    end

    context "with user status" do
      context "as a regular user" do
        before do
          SiteSetting.enable_user_status = true
          sign_in(user)
        end

        it "sets user status" do
          status = { emoji: "tooth", description: "off to dentist" }

          put "/u/#{user.username}.json", params: { status: status }
          expect(response.status).to eq(200)

          user.reload
          expect(user.user_status).not_to be_nil
          expect(user.user_status.emoji).to eq(status[:emoji])
          expect(user.user_status.description).to eq(status[:description])
        end

        it "updates user status" do
          user.set_status!("off to dentist", "tooth")
          user.reload

          new_status = { emoji: "surfing_man", description: "surfing" }
          put "/u/#{user.username}.json", params: { status: new_status }
          expect(response.status).to eq(200)

          user.reload
          expect(user.user_status).not_to be_nil
          expect(user.user_status.emoji).to eq(new_status[:emoji])
          expect(user.user_status.description).to eq(new_status[:description])
        end

        it "clears user status" do
          user.set_status!("off to dentist", "tooth")
          user.reload

          put "/u/#{user.username}.json", params: { status: nil }
          expect(response.status).to eq(200)

          user.reload
          expect(user.user_status).to be_nil
        end

        it "can't set status of another user" do
          put "/u/#{user1.username}.json",
              params: {
                status: {
                  emoji: "tooth",
                  description: "off to dentist",
                },
              }
          expect(response.status).to eq(403)

          user1.reload
          expect(user1.user_status).to be_nil
        end

        it "can't update status of another user" do
          old_status = { emoji: "tooth", description: "off to dentist" }
          user1.set_status!(old_status[:description], old_status[:emoji])
          user1.reload

          new_status = { emoji: "surfing_man", description: "surfing" }
          put "/u/#{user1.username}.json", params: { status: new_status }
          expect(response.status).to eq(403)

          user1.reload
          expect(user1.user_status).not_to be_nil
          expect(user1.user_status.emoji).to eq(old_status[:emoji])
          expect(user1.user_status.description).to eq(old_status[:description])
        end

        it "can't clear status of another user" do
          user1.set_status!("off to dentist", "tooth")
          user1.reload

          put "/u/#{user1.username}.json", params: { status: nil }
          expect(response.status).to eq(403)

          user1.reload
          expect(user1.user_status).not_to be_nil
        end

        it "doesn't clear user status if it wasn't sent in the payload" do
          new_status = { emoji: "tooth", description: "off to dentist" }
          user.set_status!(new_status[:description], new_status[:emoji])
          user.reload

          put "/u/#{user.username}.json", params: { bio_raw: "new bio" }
          expect(response.status).to eq(200)

          user.reload
          expect(user.user_status).not_to be_nil
          expect(user.user_status.emoji).to eq(new_status[:emoji])
          expect(user.user_status.description).to eq(new_status[:description])
        end

        context "when user status is disabled" do
          before { SiteSetting.enable_user_status = false }

          it "doesn't set user status" do
            put "/u/#{user.username}.json",
                params: {
                  status: {
                    emoji: "tooth",
                    description: "off to dentist",
                  },
                }
            expect(response.status).to eq(200)

            user.reload
            expect(user.user_status).to be_nil
          end

          it "doesn't update user status" do
            old_status = { emoji: "tooth", description: "off to dentist" }
            user.set_status!(old_status[:description], old_status[:emoji])
            user.reload

            new_status = { emoji: "surfing_man", description: "surfing" }
            put "/u/#{user.username}.json", params: { status: new_status }
            expect(response.status).to eq(200)

            user.reload
            expect(user.user_status).not_to be_nil
            expect(user.user_status.emoji).to eq(old_status[:emoji])
            expect(user.user_status.description).to eq(old_status[:description])
          end

          it "doesn't clear user status" do
            user.set_status!("off to dentist", "tooth")
            user.reload

            put "/u/#{user.username}.json", params: { status: nil }
            expect(response.status).to eq(200)

            user.reload
            expect(user.user_status).not_to be_nil
          end
        end
      end

      context "as a staff user" do
        before do
          SiteSetting.enable_user_status = true
          sign_in(moderator)
        end

        it "sets another user's status" do
          status = { emoji: "tooth", description: "off to dentist" }

          put "/u/#{user.username}.json", params: { status: status }
          expect(response.status).to eq(200)

          user.reload
          expect(user.user_status).not_to be_nil
          expect(user.user_status.emoji).to eq(status[:emoji])
          expect(user.user_status.description).to eq(status[:description])
        end

        it "updates another user's status" do
          user.set_status!("off to dentist", "tooth")
          user.reload

          new_status = { emoji: "surfing_man", description: "surfing" }
          put "/u/#{user.username}.json", params: { status: new_status }
          expect(response.status).to eq(200)

          user.reload
          expect(user.user_status).not_to be_nil
          expect(user.user_status.emoji).to eq(new_status[:emoji])
          expect(user.user_status.description).to eq(new_status[:description])
        end

        it "clears another user's status" do
          user.set_status!("off to dentist", "tooth")
          user.reload

          put "/u/#{user.username}.json", params: { status: nil }
          expect(response.status).to eq(200)

          user.reload
          expect(user.user_status).to be_nil
        end
      end
    end

    context "when a plugin introduces a users_controller_update_user_params modifier" do
      before { sign_in(user) }

      after { DiscoursePluginRegistry.clear_modifiers! }

      it "allows the plugin to modify the user params" do
        block_called = false

        plugin = Plugin::Instance.new
        plugin.register_modifier(
          :users_controller_update_user_params,
        ) do |result, current_user, params|
          block_called = true
          expect(current_user.id).to eq(user.id)
          result[:location] = params[:plugin_location_alias]
          result
        end

        put "/u/#{user.username}.json", params: { location: "abc", plugin_location_alias: "xyz" }

        expect(response.status).to eq(200)
        expect(user.reload.user_profile.location).to eq("xyz")
        expect(block_called).to eq(true)
      end
    end
  end

  describe "#badge_title" do
    fab!(:badge)
    let(:user_badge) { BadgeGranter.grant(badge, user1) }

    it "sets the user's title to the badge name if it is titleable" do
      sign_in(user1)

      put "/u/#{user1.username}/preferences/badge_title.json",
          params: {
            user_badge_id: user_badge.id,
          }

      expect(user1.reload.title).not_to eq(badge.display_name)
      badge.update allow_title: true

      put "/u/#{user1.username}/preferences/badge_title.json",
          params: {
            user_badge_id: user_badge.id,
          }

      expect(user1.reload.title).to eq(badge.display_name)
      expect(user1.user_profile.granted_title_badge_id).to eq(badge.id)

      badge.update allow_title: false

      put "/u/#{user1.username}/preferences/badge_title.json",
          params: {
            user_badge_id: user_badge.id,
          }

      user1.reload
      user1.user_profile.reload
      expect(user1.title).to eq("")
      expect(user1.user_profile.granted_title_badge_id).to eq(nil)
    end

    it "is not raising an erroring when user revokes title" do
      sign_in(user1)
      badge.update allow_title: true
      put "/u/#{user1.username}/preferences/badge_title.json",
          params: {
            user_badge_id: user_badge.id,
          }
      put "/u/#{user1.username}/preferences/badge_title.json", params: { user_badge_id: 0 }
      expect(response.status).to eq(200)
    end

    context "with overridden name" do
      fab!(:badge) { Fabricate(:badge, name: "Demogorgon", allow_title: true) }
      let(:user_badge) { BadgeGranter.grant(badge, user1) }

      before do
        I18n.backend.store_translations(:en, { badges: { demogorgon: { name: "D'Artagnan" } } })
        TranslationOverride.upsert!("en", "badges.demogorgon.name", "Boss")
      end

      after { TranslationOverride.revert!("en", ["badges.demogorgon.name"]) }

      it "uses the badge display name as user title" do
        sign_in(user1)

        put "/u/#{user1.username}/preferences/badge_title.json",
            params: {
              user_badge_id: user_badge.id,
            }
        expect(user1.reload.title).to eq(badge.display_name)
      end
    end
  end

  describe "#send_activation_email" do
    before do
      UsersController.any_instance.stubs(:honeypot_value).returns(nil)
      UsersController.any_instance.stubs(:challenge_value).returns(nil)
    end

    let(:post_user) do
      post "/u.json",
           params: {
             username: "osamatest",
             password: "strongpassword",
             email: "dsdsds@sasa.com",
           }

      User.find_by(username: "osamatest")
    end

    context "for an existing user" do
      context "for an activated account with email confirmed" do
        it "fails" do
          user = post_user
          email_token = Fabricate(:email_token, user: user).token
          EmailToken.confirm(email_token)

          post "/u/action/send_activation_email.json", params: { username: user.username }

          expect(response.status).to eq(409)
          expect(response.parsed_body["errors"]).to include(I18n.t("activation.activated"))
          expect(session[SessionController::ACTIVATE_USER_KEY]).to eq(nil)
        end
      end

      context "for an activated account with unconfirmed email" do
        it "should send an email" do
          user = post_user
          user.update!(active: true)
          Fabricate(:email_token, user: user)

          expect_enqueued_with(
            job: :critical_user_email,
            args: {
              type: :signup,
              to_address: user.email,
            },
          ) { post "/u/action/send_activation_email.json", params: { username: user.username } }

          expect(response.status).to eq(200)

          expect(session[SessionController::ACTIVATE_USER_KEY]).to eq(nil)
        end
      end

      context "when approval is enabled" do
        before { SiteSetting.must_approve_users = true }

        it "should raise an error" do
          user = post_user
          user.update(active: true)
          user.save!
          Fabricate(:email_token, user: user1)
          post "/u/action/send_activation_email.json", params: { username: user.username }

          expect(response.status).to eq(403)
        end
      end

      describe "when user does not have a valid session" do
        it "should not be valid" do
          post "/u/action/send_activation_email.json", params: { username: user.username }
          expect(response.status).to eq(403)
        end

        it "should allow staff regardless" do
          sign_in(admin)
          user = Fabricate(:user, active: false)
          post "/u/action/send_activation_email.json", params: { username: user.username }
          expect(response.status).to eq(200)
        end
      end

      context "with a valid email_token" do
        it "should send the activation email" do
          user = post_user

          expect_enqueued_with(job: :critical_user_email, args: { type: :signup }) do
            post "/u/action/send_activation_email.json", params: { username: user.username }
          end

          expect(response.status).to eq(200)
          expect(session[SessionController::ACTIVATE_USER_KEY]).to eq(nil)
        end
      end

      context "without an existing email_token" do
        let(:user) { post_user }
        before do
          user.email_tokens.each { |t| t.destroy }
          user.reload
        end

        it "should generate a new token" do
          expect {
            post "/u/action/send_activation_email.json", params: { username: user.username }
          }.to change { user.reload.email_tokens.count }.by(1)
        end

        it "should send an email" do
          expect do
            post "/u/action/send_activation_email.json", params: { username: user.username }
          end.to change { Jobs::CriticalUserEmail.jobs.size }.by(1)

          expect(session[SessionController::ACTIVATE_USER_KEY]).to eq(nil)
        end
      end
    end

    context "when username does not exist" do
      it "should not send an email" do
        post "/u/action/send_activation_email.json", params: { username: "nopenopenopenope" }
        expect(response.status).to eq(404)
        expect(Jobs::CriticalUserEmail.jobs.size).to eq(0)
      end
    end
  end

  describe "#pick_avatar" do
    it "raises an error when not logged in" do
      put "/u/asdf/preferences/avatar/pick.json", params: { avatar_id: 1, type: "custom" }
      expect(response.status).to eq(403)
    end

    context "while logged in" do
      before { sign_in(user1) }

      fab!(:upload) { Fabricate(:upload, user: user1) }

      it "raises an error when you don't have permission to toggle the avatar" do
        put "/u/#{another_user.username}/preferences/avatar/pick.json",
            params: {
              upload_id: upload.id,
              type: "custom",
            }

        expect(response).to be_forbidden
      end

      it "raises an error when discourse_connect_overrides_avatar is disabled" do
        SiteSetting.discourse_connect_overrides_avatar = true
        put "/u/#{user1.username}/preferences/avatar/pick.json",
            params: {
              upload_id: upload.id,
              type: "custom",
            }

        expect(response.status).to eq(422)
      end

      it "raises an error when selecting the custom/uploaded avatar and uploaded_avatars_allowed_groups is disabled" do
        SiteSetting.uploaded_avatars_allowed_groups = ""
        put "/u/#{user1.username}/preferences/avatar/pick.json",
            params: {
              upload_id: upload.id,
              type: "custom",
            }

        expect(response.status).to eq(422)
      end

      it "raises an error when selecting the custom/uploaded avatar and uploaded_avatars_allowed_groups is admin" do
        SiteSetting.uploaded_avatars_allowed_groups = "1"
        put "/u/#{user1.username}/preferences/avatar/pick.json",
            params: {
              upload_id: upload.id,
              type: "custom",
            }
        expect(response.status).to eq(422)

        user1.update!(admin: true)
        Group.refresh_automatic_groups!
        put "/u/#{user1.username}/preferences/avatar/pick.json",
            params: {
              upload_id: upload.id,
              type: "custom",
            }
        expect(response.status).to eq(200)
      end

      it "raises an error when selecting the custom/uploaded avatar and uploaded_avatars_allowed_groups is staff" do
        SiteSetting.uploaded_avatars_allowed_groups = "3"
        put "/u/#{user1.username}/preferences/avatar/pick.json",
            params: {
              upload_id: upload.id,
              type: "custom",
            }
        expect(response.status).to eq(422)

        user1.update!(moderator: true)
        Group.refresh_automatic_groups!
        put "/u/#{user1.username}/preferences/avatar/pick.json",
            params: {
              upload_id: upload.id,
              type: "custom",
            }
        expect(response.status).to eq(200)
      end

      it "raises an error when selecting the custom/uploaded avatar and uploaded_avatars_allowed_groups is a trust level" do
        SiteSetting.uploaded_avatars_allowed_groups = "13"
        put "/u/#{user1.username}/preferences/avatar/pick.json",
            params: {
              upload_id: upload.id,
              type: "custom",
            }
        expect(response.status).to eq(422)

        user1.change_trust_level!(TrustLevel[3])

        put "/u/#{user1.username}/preferences/avatar/pick.json",
            params: {
              upload_id: upload.id,
              type: "custom",
            }
        expect(response.status).to eq(200)
      end

      it "ignores the upload if picking a system avatar" do
        SiteSetting.uploaded_avatars_allowed_groups = ""
        another_upload = Fabricate(:upload)

        put "/u/#{user1.username}/preferences/avatar/pick.json",
            params: {
              upload_id: another_upload.id,
              type: "system",
            }

        expect(response.status).to eq(200)
        expect(user1.reload.uploaded_avatar_id).to eq(nil)
      end

      it "raises an error if the type is invalid" do
        SiteSetting.uploaded_avatars_allowed_groups = ""
        another_upload = Fabricate(:upload)

        put "/u/#{user1.username}/preferences/avatar/pick.json",
            params: {
              upload_id: another_upload.id,
              type: "x",
            }

        expect(response.status).to eq(422)
      end

      it "can successfully pick the system avatar" do
        put "/u/#{user1.username}/preferences/avatar/pick.json"

        expect(response.status).to eq(200)
        expect(user1.reload.uploaded_avatar_id).to eq(nil)
      end

      it "disables the use_site_small_logo_as_system_avatar setting when picking an avatar for the system user" do
        system_user = Discourse.system_user
        SiteSetting.use_site_small_logo_as_system_avatar = true
        another_upload = Fabricate(:upload, user: system_user)
        sign_in(system_user)

        put "/u/#{system_user.username}/preferences/avatar/pick.json",
            params: {
              upload_id: another_upload.id,
              type: "uploaded",
            }

        expect(response.status).to eq(200)
        expect(SiteSetting.use_site_small_logo_as_system_avatar).to eq(false)
      end

      it "can successfully pick a gravatar" do
        user1.user_avatar.update_columns(gravatar_upload_id: upload.id)

        put "/u/#{user1.username}/preferences/avatar/pick.json",
            params: {
              upload_id: upload.id,
              type: "gravatar",
            }

        expect(response.status).to eq(200)
        expect(user1.reload.uploaded_avatar_id).to eq(upload.id)
        expect(user1.user_avatar.reload.gravatar_upload_id).to eq(upload.id)
      end

      it "can not pick uploads that were not created by user" do
        upload2 = Fabricate(:upload)

        put "/u/#{user1.username}/preferences/avatar/pick.json",
            params: {
              upload_id: upload2.id,
              type: "custom",
            }

        expect(response.status).to eq(403)
      end

      it "can successfully pick a custom avatar" do
        events =
          DiscourseEvent.track_events do
            put "/u/#{user1.username}/preferences/avatar/pick.json",
                params: {
                  upload_id: upload.id,
                  type: "custom",
                }
          end

        expect(events.map { |event| event[:event_name] }).to include(:user_updated)
        expect(response.status).to eq(200)
        expect(user1.reload.uploaded_avatar_id).to eq(upload.id)
        expect(user1.user_avatar.reload.custom_upload_id).to eq(upload.id)
      end
    end
  end

  describe "#select_avatar" do
    it "raises an error when not logged in" do
      put "/u/asdf/preferences/avatar/select.json", params: { url: "https://meta.discourse.org" }
      expect(response.status).to eq(403)
    end

    context "while logged in" do
      before { sign_in(user1) }

      fab!(:avatar1) { Fabricate(:upload) }
      fab!(:avatar2) { Fabricate(:upload) }
      let(:url) { "https://www.discourse.org" }

      it "raises an error when url is blank" do
        put "/u/#{user1.username}/preferences/avatar/select.json", params: { url: "" }
        expect(response.status).to eq(422)
      end

      it "raises an error when selectable avatars is disabled" do
        put "/u/#{user1.username}/preferences/avatar/select.json", params: { url: url }
        expect(response.status).to eq(422)
      end

      context "when selectable avatars is enabled" do
        before do
          SiteSetting.selectable_avatars = [avatar1, avatar2]
          SiteSetting.selectable_avatars_mode = "no_one"
        end

        it "raises an error when selectable avatars is empty" do
          SiteSetting.selectable_avatars = ""
          put "/u/#{user1.username}/preferences/avatar/select.json", params: { url: url }
          expect(response.status).to eq(422)
        end

        context "when selectable avatars is properly setup" do
          it "raises an error when url is not in selectable avatars list" do
            put "/u/#{user1.username}/preferences/avatar/select.json", params: { url: url }
            expect(response.status).to eq(422)
          end

          it "can successfully select an avatar" do
            events =
              DiscourseEvent.track_events do
                put "/u/#{user1.username}/preferences/avatar/select.json",
                    params: {
                      url: avatar1.url,
                    }
              end

            expect(events.map { |event| event[:event_name] }).to include(:user_updated)
            expect(response.status).to eq(200)
            expect(user1.reload.uploaded_avatar_id).to eq(avatar1.id)
            expect(user1.user_avatar.reload.custom_upload_id).to eq(avatar1.id)
          end

          it "can successfully select an avatar using a cooked URL" do
            events =
              DiscourseEvent.track_events do
                put "/u/#{user1.username}/preferences/avatar/select.json",
                    params: {
                      url: UrlHelper.cook_url(avatar1.url),
                    }
              end

            expect(events.map { |event| event[:event_name] }).to include(:user_updated)
            expect(response.status).to eq(200)
            expect(user1.reload.uploaded_avatar_id).to eq(avatar1.id)
            expect(user1.user_avatar.reload.custom_upload_id).to eq(avatar1.id)
          end

          it "disables the use_site_small_logo_as_system_avatar setting when picking an avatar for the system user" do
            system_user = Discourse.system_user
            SiteSetting.use_site_small_logo_as_system_avatar = true
            sign_in(system_user)

            put "/u/#{system_user.username}/preferences/avatar/select.json",
                params: {
                  url: UrlHelper.cook_url(avatar1.url),
                }

            expect(response.status).to eq(200)
            expect(SiteSetting.use_site_small_logo_as_system_avatar).to eq(false)
          end
        end
      end
    end
  end

  describe "#destroy_user_image" do
    it "raises an error when not logged in" do
      delete "/u/asdf/preferences/user_image.json", params: { type: "profile_background" }
      expect(response.status).to eq(403)
    end

    context "while logged in" do
      before { sign_in(user1) }

      it 'raises an error when you don\'t have permission to clear the profile background' do
        delete "/u/#{another_user.username}/preferences/user_image.json",
               params: {
                 type: "profile_background",
               }
        expect(response).to be_forbidden
      end

      it "requires the `type` param" do
        delete "/u/#{user1.username}/preferences/user_image.json"
        expect(response.status).to eq(400)
      end

      it "only allows certain `types`" do
        delete "/u/#{user1.username}/preferences/user_image.json", params: { type: "wat" }
        expect(response.status).to eq(400)
      end

      it "can clear the profile background" do
        delete "/u/#{user1.username}/preferences/user_image.json",
               params: {
                 type: "profile_background",
               }

        expect(user1.reload.profile_background_upload).to eq(nil)
        expect(response.status).to eq(200)
      end
    end
  end

  describe "#destroy" do
    it "raises an error when not logged in" do
      delete "/u/nobody.json"
      expect(response.status).to eq(403)
    end

    context "while logged in" do
      before { sign_in(user1) }

      it "raises an error when you cannot delete your account" do
        UserDestroyer.any_instance.expects(:destroy).never
        stat = user1.user_stat
        stat.post_count = 3
        stat.save!
        delete "/u/#{user1.username}.json"
        expect(response).to be_forbidden
      end

      it "raises an error when you try to delete someone else's account" do
        UserDestroyer.any_instance.expects(:destroy).never
        delete "/u/#{another_user.username}.json"
        expect(response).to be_forbidden
      end

      it "deletes your account when you're allowed to" do
        UserDestroyer.any_instance.expects(:destroy).with(user1, anything).returns(user1)
        delete "/u/#{user1.username}.json"
        expect(response.status).to eq(200)
      end
    end
  end

  describe "#notification_level" do
    it "raises an error when `notification_level` param is not a valid value" do
      sign_in(user)
      invalid_arg = "invalid"
      put "/u/#{user.username}/notification_level.json", params: { notification_level: invalid_arg }
      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"].first).to eq(
        I18n.t("notification_level.invalid_value", value: invalid_arg),
      )
    end
  end

  describe "#ignore" do
    it "raises an error when not logged in" do
      put "/u/#{user1.username}/notification_level.json", params: { notification_level: "" }
      expect(response.status).to eq(403)
    end

    context "while logged in" do
      fab!(:user) { Fabricate(:user, trust_level: 2) }
      before { sign_in(user) }

      fab!(:ignored_user) { Fabricate(:ignored_user, user: user, ignored_user: another_user) }
      fab!(:muted_user) { Fabricate(:muted_user, user: user, muted_user: another_user) }

      context "when you can't change the notification" do
        fab!(:staff_user) { admin }

        it "ignoring includes a helpful error message" do
          put "/u/#{staff_user.username}/notification_level.json",
              params: {
                notification_level: "ignore",
              }
          expect(response.status).to eq(422)
          expect(response.parsed_body["errors"][0]).to eq(I18n.t("notification_level.ignore_error"))
        end

        it "muting includes a helpful error message" do
          put "/u/#{staff_user.username}/notification_level.json",
              params: {
                notification_level: "mute",
              }
          expect(response.status).to eq(422)
          expect(response.parsed_body["errors"][0]).to eq(I18n.t("notification_level.mute_error"))
        end
      end

      context "when changing notification level to normal" do
        it "changes notification level to normal" do
          put "/u/#{another_user.username}/notification_level.json",
              params: {
                notification_level: "normal",
              }
          expect(IgnoredUser.count).to eq(0)
          expect(MutedUser.count).to eq(0)
        end
      end

      context "when changing notification level to mute" do
        it "changes notification level to mute" do
          put "/u/#{another_user.username}/notification_level.json",
              params: {
                notification_level: "mute",
              }
          expect(IgnoredUser.count).to eq(0)
          expect(MutedUser.find_by(user_id: user.id, muted_user_id: another_user.id)).to be_present
        end
      end

      context "when changing notification level to ignore" do
        it "changes notification level to ignore" do
          put "/u/#{another_user.username}/notification_level.json",
              params: {
                notification_level: "ignore",
                expiring_at: 3.days.from_now,
              }
          expect(response.status).to eq(200)
          expect(MutedUser.count).to eq(0)
          expect(
            IgnoredUser.find_by(user_id: user.id, ignored_user_id: another_user.id),
          ).to be_present
        end

        it "allows admin to change the ignore status for a source user" do
          ignored_user.destroy!
          sign_in(Fabricate(:user, admin: true))
          put "/u/#{another_user.username}/notification_level.json",
              params: {
                notification_level: "ignore",
                acting_user_id: user.id,
                expiring_at: 3.days.from_now,
              }
          expect(response.status).to eq(200)
          expect(
            IgnoredUser.find_by(user_id: user.id, ignored_user_id: another_user.id),
          ).to be_present
        end

        it "does not allow a regular user to change the ignore status for anyone but themself" do
          ignored_user.destroy!
          acting_user = Fabricate(:user)
          put "/u/#{another_user.username}/notification_level.json",
              params: {
                notification_level: "ignore",
                acting_user_id: acting_user.id,
                expiring_at: 3.days.from_now,
              }
          expect(response.status).to eq(422)
          expect(
            IgnoredUser.find_by(user_id: acting_user.id, ignored_user_id: another_user.id),
          ).to eq(nil)

          put "/u/#{another_user.username}/notification_level.json",
              params: {
                notification_level: "ignore",
                expiring_at: 3.days.from_now,
              }
          expect(response.status).to eq(200)
          expect(
            IgnoredUser.find_by(user_id: user.id, ignored_user_id: another_user.id),
          ).to be_present
        end

        context "when expiring_at param is set" do
          it "changes notification level to ignore" do
            freeze_time do
              expiring_at = 3.days.from_now
              put "/u/#{another_user.username}/notification_level.json",
                  params: {
                    notification_level: "ignore",
                    expiring_at: expiring_at,
                  }

              ignored_user = IgnoredUser.find_by(user_id: user.id, ignored_user_id: another_user.id)
              expect(ignored_user).to be_present
              expect(ignored_user.expiring_at.to_i).to eq(expiring_at.to_i)
              expect(MutedUser.count).to eq(0)
            end
          end
        end
      end
    end
  end

  describe "for user with period in username" do
    fab!(:user_with_period) { Fabricate(:user, username: "myname.test") }

    it "still works" do
      sign_in(user_with_period)
      UserDestroyer
        .any_instance
        .expects(:destroy)
        .with(user_with_period, anything)
        .returns(user_with_period)
      delete "/u/#{user_with_period.username}", xhr: true
      expect(response.status).to eq(200)
    end
  end

  describe "#my_redirect" do
    it "redirects if the user is not logged in" do
      get "/my/wat"
      expect(response).to redirect_to("/login-preferences")
      expect(response.cookies).to have_key("destination_url")
      expect(response.cookies["destination_url"]).to eq("/my/wat")
      expect(response.headers["X-Robots-Tag"]).to eq("noindex")
    end

    context "when the user is logged in" do
      before { sign_in(user1) }

      it "will not redirect to an invalid path" do
        get "/my/wat/..password.txt"
        expect(response).not_to be_redirect
      end

      it "will redirect to an valid path" do
        get "/my/preferences"
        expect(response).to redirect_to("/u/#{user1.username}/preferences")
      end

      it "permits forward slashes" do
        get "/my/activity/posts"
        expect(response).to redirect_to("/u/#{user1.username}/activity/posts")
      end

      it "correctly redirects for Unicode usernames" do
        SiteSetting.unicode_usernames = true
        user = sign_in(Fabricate(:unicode_user))

        get "/my/preferences"
        expect(response).to redirect_to("/u/#{user.encoded_username}/preferences")
      end
    end
  end

  describe "#check_emails" do
    it "raises an error when not logged in" do
      get "/u/zogstrip/emails.json"
      expect(response.status).to eq(403)
    end

    context "while logged in" do
      let(:sign_in_admin) { sign_in(admin) }

      it "raises an error when you aren't allowed to check emails" do
        sign_in(Fabricate(:user))
        get "/u/#{Fabricate(:user).username}/emails.json"
        expect(response).to be_forbidden
      end

      it "returns emails and associated_accounts for self" do
        Fabricate(:email_change_request, user: user1)
        sign_in(user)

        get "/u/#{user.username}/emails.json"

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["email"]).to eq(user.email)
        expect(json["secondary_emails"]).to eq(user.secondary_emails)
        expect(json["unconfirmed_emails"]).to eq(user.unconfirmed_emails)
        expect(json["associated_accounts"]).to eq([])
      end

      it "returns emails and associated_accounts when you're allowed to see them" do
        Fabricate(:email_change_request, user: user1)
        sign_in_admin

        get "/u/#{user.username}/emails.json"

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["email"]).to eq(user.email)
        expect(json["secondary_emails"]).to eq(user.secondary_emails)
        expect(json["unconfirmed_emails"]).to eq(user.unconfirmed_emails)
        expect(json["associated_accounts"]).to eq([])
      end

      it "works on inactive users" do
        inactive_user = Fabricate(:user, active: false)
        Fabricate(:email_change_request, user: inactive_user)
        sign_in_admin

        get "/u/#{inactive_user.username}/emails.json"

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["email"]).to eq(inactive_user.email)
        expect(json["secondary_emails"]).to eq(inactive_user.secondary_emails)
        expect(json["unconfirmed_emails"]).to eq(inactive_user.unconfirmed_emails)
        expect(json["associated_accounts"]).to eq([])
      end
    end
  end

  describe "#check_sso_email" do
    it "raises an error when not logged in" do
      get "/u/zogstrip/sso-email.json"
      expect(response.status).to eq(403)
    end

    context "while logged in" do
      let(:sign_in_admin) { sign_in(admin) }

      it "raises an error when you aren't allowed to check sso email" do
        sign_in(Fabricate(:user))
        get "/u/#{user1.username}/sso-email.json"
        expect(response).to be_forbidden
      end

      it "returns emails and associated_accounts when you're allowed to see them" do
        user1.single_sign_on_record =
          SingleSignOnRecord.create(
            user_id: user1.id,
            external_email: "foobar@example.com",
            external_id: "example",
            last_payload: "looks good",
          )
        sign_in_admin

        get "/u/#{user1.username}/sso-email.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["email"]).to eq("foobar@example.com")
      end
    end
  end

  describe "#check_sso_payload" do
    it "raises an error when not logged in" do
      get "/u/zogstrip/sso-payload.json"
      expect(response.status).to eq(403)
    end

    context "while logged in" do
      let(:sign_in_admin) { sign_in(admin) }

      it "raises an error when you aren't allowed to check sso payload" do
        sign_in(Fabricate(:user))
        get "/u/#{user1.username}/sso-payload.json"
        expect(response).to be_forbidden
      end

      it "returns SSO payload when you're allowed to see" do
        user1.single_sign_on_record =
          SingleSignOnRecord.create(
            user_id: user1.id,
            external_email: "foobar@example.com",
            external_id: "example",
            last_payload: "foobar",
          )
        sign_in_admin

        get "/u/#{user1.username}/sso-payload.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["payload"]).to eq("foobar")
      end
    end
  end

  describe "#update_primary_email" do
    let(:user_email) { user1.primary_email }
    fab!(:other_email) { Fabricate(:secondary_email, user: user1) }

    before do
      SiteSetting.email_editable = true

      sign_in(user1)
    end

    it "changes user's primary email" do
      put "/u/#{user1.username}/preferences/primary-email.json", params: { email: user_email.email }
      expect(response.status).to eq(200)
      expect(user_email.reload.primary).to eq(true)
      expect(other_email.reload.primary).to eq(false)

      event =
        DiscourseEvent
          .track_events do
            expect {
              put "/u/#{user1.username}/preferences/primary-email.json",
                  params: {
                    email: other_email.email,
                  }
            }.to change {
              UserHistory.where(
                action: UserHistory.actions[:update_email],
                acting_user_id: user1.id,
              ).count
            }.by(1)
          end
          .last

      expect(response.status).to eq(200)
      expect(user_email.reload.primary).to eq(false)
      expect(other_email.reload.primary).to eq(true)

      expect(event[:event_name]).to eq(:user_updated)
      expect(event[:params].first).to eq(user1)
    end
  end

  describe "#destroy_email" do
    fab!(:user_email) { user1.primary_email }
    fab!(:other_email) { Fabricate(:secondary_email, user: user1) }

    before do
      SiteSetting.email_editable = true

      sign_in(user1)
    end

    it "can destroy secondary emails" do
      delete "/u/#{user1.username}/preferences/email.json", params: { email: user_email.email }
      expect(response.status).to eq(428)
      expect(user1.reload.user_emails.pluck(:email)).to contain_exactly(
        user_email.email,
        other_email.email,
      )

      event =
        DiscourseEvent
          .track_events do
            expect {
              delete "/u/#{user1.username}/preferences/email.json",
                     params: {
                       email: other_email.email,
                     }
            }.to change {
              UserHistory.where(
                action: UserHistory.actions[:destroy_email],
                acting_user_id: user1.id,
              ).count
            }.by(1)
          end
          .last

      expect(response.status).to eq(200)
      expect(user1.reload.user_emails.pluck(:email)).to contain_exactly(user_email.email)

      expect(event[:event_name]).to eq(:user_updated)
      expect(event[:params].first).to eq(user1)
    end

    it "can destroy unconfirmed emails" do
      request_1 =
        EmailChangeRequest.create!(
          user: user1,
          new_email: user_email.email,
          change_state: EmailChangeRequest.states[:authorizing_new],
        )

      EmailChangeRequest.create!(
        user: user1,
        new_email: other_email.email,
        change_state: EmailChangeRequest.states[:authorizing_new],
      )

      EmailChangeRequest.create!(
        user: user1,
        new_email: other_email.email,
        change_state: EmailChangeRequest.states[:authorizing_new],
      )

      delete "/u/#{user1.username}/preferences/email.json", params: { email: other_email.email }

      expect(user1.user_emails.pluck(:email)).to contain_exactly(
        user_email.email,
        other_email.email,
      )
      expect(user1.email_change_requests).to contain_exactly(request_1)
    end

    it "destroys associated email tokens and email change requests" do
      new_email = "new.n.cool@example.com"
      updater = EmailUpdater.new(guardian: user1.guardian, user: user1)
      updater.change_to(new_email)

      email_token = updater.change_req.new_email_token
      expect(email_token).to be_present

      delete "/u/#{user1.username}/preferences/email.json", params: { email: new_email }

      expect(EmailToken.find_by(id: email_token.id)).to eq(nil)
      expect(EmailChangeRequest.find_by(id: updater.change_req.id)).to eq(nil)
    end
  end

  describe "#topic_tracking_state" do
    context "when anon" do
      it "raises an error on anon for topic_tracking_state" do
        get "/u/#{user1.username}/topic-tracking-state.json"
        expect(response.status).to eq(403)
      end
    end

    context "when logged on" do
      it "detects new topic" do
        sign_in(user1)

        topic = Fabricate(:topic)
        get "/u/#{user1.username}/topic-tracking-state.json"

        expect(response.status).to eq(200)
        states = response.parsed_body
        expect(states[0]["topic_id"]).to eq(topic.id)
      end
    end
  end

  describe "#summary" do
    it "generates summary info" do
      create_post(user: user)

      get "/u/#{user.username_lower}/summary.json"
      expect(response.headers["X-Robots-Tag"]).to eq("noindex")
      expect(response.status).to eq(200)
      json = response.parsed_body

      expect(json["user_summary"]["topic_count"]).to eq(1)
      expect(json["user_summary"]["post_count"]).to eq(0)
    end

    context "when `hide_user_profiles_from_public` site setting is enabled" do
      before { SiteSetting.hide_user_profiles_from_public = true }

      it "returns 200 for logged in users" do
        sign_in(Fabricate(:user))

        get "/u/#{user.username_lower}/summary.json"

        expect(response.status).to eq(200)
      end

      it "returns 403 for anonymous users" do
        get "/u/#{user.username_lower}/summary.json"

        expect(response.status).to eq(403)
      end
    end

    context "when `hide_profile` user option is checked" do
      before_all { user1.user_option.update_columns(hide_profile: true) }

      it "returns 404" do
        get "/u/#{user1.username_lower}/summary.json"
        expect(response.status).to eq(404)
      end

      it "returns summary info if `allow_users_to_hide_profile` is false" do
        SiteSetting.allow_users_to_hide_profile = false

        get "/u/#{user1.username_lower}/summary.json"
        expect(response.status).to eq(200)
      end
    end

    context "with avatar flair in Most... sections" do
      it "returns data for automatic groups flair" do
        liker = Fabricate(:user, admin: true, moderator: true, trust_level: 1)
        create_and_like_post(user_deferred, liker)

        get "/u/#{user_deferred.username_lower}/summary.json"
        json = response.parsed_body

        expect(json["user_summary"]["most_liked_by_users"][0]["admin"]).to eq(true)
        expect(json["user_summary"]["most_liked_by_users"][0]["moderator"]).to eq(true)
        expect(json["user_summary"]["most_liked_by_users"][0]["trust_level"]).to eq(1)
      end

      it "returns data for flair when an icon is used" do
        group =
          Fabricate(
            :group,
            name: "Groupie",
            flair_bg_color: "#111111",
            flair_color: "#999999",
            flair_icon: "icon",
          )
        liker = Fabricate(:user, flair_group: group, refresh_auto_groups: true)
        create_and_like_post(user_deferred, liker)

        get "/u/#{user_deferred.username_lower}/summary.json"
        json = response.parsed_body

        expect(json["user_summary"]["most_liked_by_users"][0]["flair_name"]).to eq("Groupie")
        expect(json["user_summary"]["most_liked_by_users"][0]["flair_url"]).to eq("icon")
        expect(json["user_summary"]["most_liked_by_users"][0]["flair_bg_color"]).to eq("#111111")
        expect(json["user_summary"]["most_liked_by_users"][0]["flair_color"]).to eq("#999999")
      end

      it "returns data for flair when an image is used" do
        upload = Fabricate(:upload)
        group = Fabricate(:group, name: "Groupie", flair_bg_color: "#111111", flair_upload: upload)
        liker = Fabricate(:user, flair_group: group)
        create_and_like_post(user_deferred, liker)

        get "/u/#{user_deferred.username_lower}/summary.json"
        json = response.parsed_body

        expect(json["user_summary"]["most_liked_by_users"][0]["flair_name"]).to eq("Groupie")
        expect(json["user_summary"]["most_liked_by_users"][0]["flair_url"]).to eq(upload.url)
        expect(json["user_summary"]["most_liked_by_users"][0]["flair_bg_color"]).to eq("#111111")
      end

      def create_and_like_post(likee, liker)
        UserActionManager.enable
        post = create_post(user: likee)
        PostActionCreator.like(liker, post)
      end
    end
  end

  describe "#confirm_admin" do
    it "fails without a valid token" do
      get "/u/confirm-admin/invalid-token.json"
      expect(response).not_to be_successful
    end

    it "fails with a missing token" do
      get "/u/confirm-admin/a0a0a0a0a0.json"
      expect(response).to_not be_successful
    end

    it "succeeds with a valid code as anonymous" do
      ac = AdminConfirmation.new(user1, admin)
      ac.create_confirmation
      get "/u/confirm-admin/#{ac.token}.json"
      expect(response.status).to eq(200)

      user1.reload
      expect(user1.admin?).to eq(false)
    end

    it "succeeds with a valid code when logged in as that user" do
      sign_in(admin)

      ac = AdminConfirmation.new(user1, admin)
      ac.create_confirmation
      get "/u/confirm-admin/#{ac.token}.json", params: { token: ac.token }
      expect(response.status).to eq(200)

      user1.reload
      expect(user1.admin?).to eq(false)
    end

    it "fails if you're logged in as a different account" do
      sign_in(admin)

      ac = AdminConfirmation.new(user1, Fabricate(:admin))
      ac.create_confirmation
      get "/u/confirm-admin/#{ac.token}.json"
      expect(response).to_not be_successful

      user1.reload
      expect(user1.admin?).to eq(false)
    end

    describe "post" do
      it "gives the user admin access when POSTed" do
        ac = AdminConfirmation.new(user1, admin)
        ac.create_confirmation
        post "/u/confirm-admin/#{ac.token}.json"
        expect(response.status).to eq(200)

        user1.reload
        expect(user1.admin?).to eq(true)
      end
    end
  end

  describe "#update_activation_email" do
    before do
      UsersController.any_instance.stubs(:honeypot_value).returns(nil)
      UsersController.any_instance.stubs(:challenge_value).returns(nil)
    end

    let(:post_user) do
      post "/u.json",
           params: {
             username: "osamatest",
             password: "strongpassword",
             email: "osama@example.com",
           }
      user = User.where(username: "osamatest").first
      user.active = false
      user.save!
      user
    end

    context "with a session variable" do
      it "raises an error with an invalid session value" do
        post_user

        post "/u.json",
             params: {
               username: "osamatest2",
               password: "strongpassword2",
               email: "osama22@example.com",
             }
        user = User.where(username: "osamatest2").first
        user.destroy

        put "/u/update-activation-email.json", params: { email: "osamaupdated@example.com" }

        expect(response.status).to eq(403)
      end

      it "raises an error for an active user" do
        user = post_user
        user.update(active: true)
        user.save!

        put "/u/update-activation-email.json", params: { email: "osama@example.com" }

        expect(response.status).to eq(403)
      end

      it "raises an error when logged in" do
        sign_in(moderator)
        post_user

        put "/u/update-activation-email.json", params: { email: "updatedemail@example.com" }

        expect(response.status).to eq(403)
      end

      it "raises an error when the new email is taken" do
        active_user = Fabricate(:user)
        post_user

        put "/u/update-activation-email.json", params: { email: active_user.email }

        expect(response.status).to eq(422)
      end

      it "raises an error when the email is blocklisted" do
        post_user
        SiteSetting.blocked_email_domains = "example.com"
        put "/u/update-activation-email.json", params: { email: "test@example.com" }
        expect(response.status).to eq(422)
      end

      it "can be updated" do
        user = post_user
        token = user.email_tokens.first

        put "/u/update-activation-email.json", params: { email: "updatedemail@example.com" }

        expect(response.status).to eq(200)

        user.reload
        expect(user.email).to eq("updatedemail@example.com")
        expect(
          user.email_tokens.where(email: "updatedemail@example.com", expired: false),
        ).to be_present

        expect(EmailToken.find_by(id: token.id)).to eq(nil)
      end

      it "tells the user to slow down after many requests" do
        RateLimiter.enable
        freeze_time

        user = post_user
        token = user.email_tokens.first

        6.times do |n|
          put "/u/update-activation-email.json",
              params: {
                email: "updatedemail#{n}@example.com",
              },
              env: {
                REMOTE_ADDR: "1.2.3.#{n}",
              }
        end

        expect(response.status).to eq(429)
      end
    end

    context "with a username and password" do
      it "raises an error with an invalid username" do
        put "/u/update-activation-email.json",
            params: {
              username: "eviltrout",
              password: "invalid-password",
              email: "updatedemail@example.com",
            }

        expect(response.status).to eq(403)
      end

      it "raises an error with an invalid password" do
        put "/u/update-activation-email.json",
            params: {
              username: inactive_user.username,
              password: "invalid-password",
              email: "updatedemail@example.com",
            }

        expect(response.status).to eq(403)
      end

      it "raises an error for an active user" do
        put "/u/update-activation-email.json",
            params: {
              username: Fabricate(:walter_white).username,
              password: "letscook",
              email: "updatedemail@example.com",
            }

        expect(response.status).to eq(403)
      end

      it "raises an error when logged in" do
        sign_in(moderator)

        put "/u/update-activation-email.json",
            params: {
              username: inactive_user.username,
              password: "qwerqwer123",
              email: "updatedemail@example.com",
            }

        expect(response.status).to eq(403)
      end

      it "raises an error when the new email is taken" do
        put "/u/update-activation-email.json",
            params: {
              username: inactive_user.username,
              password: "qwerqwer123",
              email: user.email,
            }

        expect(response.status).to eq(422)
      end

      it "can be updated" do
        user = inactive_user
        token = user.email_tokens.first

        put "/u/update-activation-email.json",
            params: {
              username: user.username,
              password: "qwerqwer123",
              email: "updatedemail@example.com",
            }

        expect(response.status).to eq(200)

        user.reload
        expect(user.email).to eq("updatedemail@example.com")
        expect(
          user.email_tokens.where(email: "updatedemail@example.com", expired: false),
        ).to be_present

        expect(EmailToken.find_by(id: token.id)).to eq(nil)
      end

      it "tells the user to slow down after many requests" do
        RateLimiter.enable
        freeze_time

        user = inactive_user
        token = user.email_tokens.first

        6.times do |n|
          put "/u/update-activation-email.json",
              params: {
                username: user.username,
                password: "qwerqwer123",
                email: "updatedemail#{n}@example.com",
              },
              env: {
                REMOTE_ADDR: "1.2.3.#{n}",
              }
        end

        expect(response.status).to eq(429)
      end
    end
  end

  describe "#show" do
    context "when anon" do
      let(:user) { Discourse.system_user }

      it "returns success" do
        get "/u/#{user.username}.json"
        expect(response.status).to eq(200)
        parsed = response.parsed_body["user"]

        expect(parsed["username"]).to eq(user.username)
        expect(parsed["profile_hidden"]).to be_blank
        expect(parsed["trust_level"]).to be_present
        expect(response.headers["X-Robots-Tag"]).to eq("noindex")
      end

      it "returns a hidden profile" do
        user.user_option.update_column(:hide_profile, true)

        get "/u/#{user.username}.json"
        expect(response.status).to eq(200)
        parsed = response.parsed_body["user"]

        expect(parsed["username"]).to eq(user.username)
        expect(parsed["profile_hidden"]).to eq(true)
        expect(parsed["trust_level"]).to be_blank
        expect(response.headers["X-Robots-Tag"]).to eq("noindex")
      end

      it "should 403 for anonymous user when profiles are hidden" do
        SiteSetting.hide_user_profiles_from_public = true
        get "/u/#{user.username}.json"
        expect(response.headers["X-Robots-Tag"]).to eq("noindex")
        expect(response).to have_http_status(:forbidden)
        get "/u/#{user.username}/messages.json"
        expect(response).to have_http_status(:forbidden)
      end

      it "should 403 correctly for crawlers when profiles are hidden" do
        SiteSetting.hide_user_profiles_from_public = true
        get "/u/#{user.username}", headers: { "User-Agent" => "Googlebot" }
        expect(response).to have_http_status(:forbidden)
        expect(response.body).to have_tag("body.crawler")
        expect(response.headers["X-Robots-Tag"]).to eq("noindex")
      end

      describe "user profile views" do
        it "should track a user profile view for an anon user" do
          get "/"
          UserProfileView.expects(:add).with(another_user.user_profile.id, request.remote_ip, nil)
          get "/u/#{another_user.username}.json"
        end

        it "skips tracking" do
          UserProfileView.expects(:add).never
          get "/u/#{user.username}.json", params: { skip_track_visit: true }
        end
      end
    end

    context "when logged in" do
      before { sign_in(user1) }

      it "returns success" do
        get "/u/#{user1.username}.json"
        expect(response.status).to eq(200)
        expect(response.headers["X-Robots-Tag"]).to eq("noindex")

        json = response.parsed_body

        expect(json["user"]["has_title_badges"]).to eq(false)
      end

      it "returns not found when the username doesn't exist" do
        get "/u/madeuppity.json"
        expect(response).not_to be_successful
        expect(response.headers["X-Robots-Tag"]).to eq("noindex")
      end

      it "returns not found when the user is inactive" do
        inactive = Fabricate(:user, active: false)
        get "/u/#{inactive.username}.json"
        expect(response).not_to be_successful
        expect(response.headers["X-Robots-Tag"]).to eq("noindex")
      end

      it "returns success when show_inactive_accounts is true and user is logged in" do
        SiteSetting.show_inactive_accounts = true
        inactive = Fabricate(:user, active: false)
        get "/u/#{inactive.username}.json"
        expect(response.status).to eq(200)
      end

      it "raises an error on invalid access" do
        Guardian.any_instance.expects(:can_see?).with(user1).returns(false)
        get "/u/#{user1.username}.json"
        expect(response).to be_forbidden
        expect(response.headers["X-Robots-Tag"]).to eq("noindex")
      end

      describe "user profile views" do
        it "should track a user profile view for a signed in user" do
          UserProfileView.expects(:add).with(
            another_user.user_profile.id,
            request.remote_ip,
            user1.id,
          )
          get "/u/#{another_user.username}.json"
        end

        it "should not track a user profile view for a user viewing his own profile" do
          UserProfileView.expects(:add).never
          get "/u/#{user1.username}.json"
        end

        it "skips tracking" do
          UserProfileView.expects(:add).never
          get "/u/#{user1.username}.json", params: { skip_track_visit: true }
        end
      end

      context "when fetching a user by external_id" do
        before { user1.create_single_sign_on_record(external_id: "997", last_payload: "") }

        it "returns fetch for a matching external_id" do
          get "/u/by-external/997.json"
          expect(response.status).to eq(200)
          expect(response.parsed_body["user"]["username"]).to eq(user1.username)
        end

        it "returns not found when external_id doesn't match" do
          get "/u/by-external/99.json"
          expect(response).not_to be_successful
        end

        context "for an external provider" do
          before do
            sign_in(admin)
            SiteSetting.enable_google_oauth2_logins = true
            UserAssociatedAccount.create!(
              user: user1,
              provider_uid: "myuid",
              provider_name: "google_oauth2",
            )
          end

          it "doesn't work for non-admin" do
            sign_in(user1)
            get "/u/by-external/google_oauth2/myuid.json"
            expect(response.status).to eq(403)
          end

          it "can fetch the user" do
            get "/u/by-external/google_oauth2/myuid.json"
            expect(response.status).to eq(200)
            expect(response.parsed_body["user"]["username"]).to eq(user1.username)
          end

          it "fails for disabled provider" do
            SiteSetting.enable_google_oauth2_logins = false
            get "/u/by-external/google_oauth2/myuid.json"
            expect(response.status).to eq(404)
          end

          it "returns 404 for missing user" do
            get "/u/by-external/google_oauth2/myotheruid.json"
            expect(response.status).to eq(404)
          end
        end
      end

      describe "include_post_count_for" do
        fab!(:topic)

        before_all do
          Fabricate(:post, user: user1, topic: topic)
          Fabricate(:post, user: admin, topic: topic)
          Fabricate(:post, user: admin, topic: topic, post_type: Post.types[:whisper])
        end

        it "includes only visible posts" do
          get "/u/#{admin.username}.json", params: { include_post_count_for: topic.id }
          topic_post_count = response.parsed_body.dig("user", "topic_post_count")
          expect(topic_post_count[topic.id.to_s]).to eq(1)
        end

        it "doesn't include the post count when the signed in user doesn't have access" do
          c = Fabricate(:category, read_restricted: true)
          topic.update(category_id: c.id)
          expect(Guardian.new(user1).can_see?(topic)).to eq(false)
          get "/u/#{admin.username}.json", params: { include_post_count_for: topic.id }
          topic_post_count = response.parsed_body.dig("user", "topic_post_count")
          expect(topic_post_count).to eq(nil)
        end

        it "includes all post types for staff members" do
          SiteSetting.whispers_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}"
          sign_in(admin)

          get "/u/#{admin.username}.json", params: { include_post_count_for: topic.id }
          topic_post_count = response.parsed_body.dig("user", "topic_post_count")
          expect(topic_post_count[topic.id.to_s]).to eq(2)
        end
      end
    end

    it "should be able to view a user" do
      get "/u/#{user1.username}"

      expect(response.status).to eq(200)
      expect(response.body).to include(user1.username)
    end

    it "should not be able to view a private user profile" do
      user1.user_profile.update!(bio_raw: "Hello world!")
      user1.user_option.update!(hide_profile: true)

      get "/u/#{user1.username}"

      expect(response.status).to eq(200)
      expect(response.body).not_to include("Hello world!")
    end

    describe "when username contains a period" do
      before_all { user1.update!(username: "test.test") }

      it "should be able to view a user" do
        get "/u/#{user1.username}"

        expect(response.status).to eq(200)
        expect(response.body).to include(user1.username)
      end
    end
  end

  describe "#show_card" do
    context "when anon" do
      let(:user) { Discourse.system_user }

      it "returns success" do
        get "/u/#{user.username}/card.json"
        expect(response.status).to eq(200)
        parsed = response.parsed_body["user"]

        expect(parsed["username"]).to eq(user.username)
        expect(parsed["profile_hidden"]).to be_blank
        expect(parsed["trust_level"]).to be_present
      end

      it "should have http status 403 for anonymous user when profiles are hidden" do
        SiteSetting.hide_user_profiles_from_public = true
        get "/u/#{user.username}/card.json"
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when logged in" do
      before { sign_in(user1) }

      it "works correctly" do
        get "/u/#{user.username}/card.json"
        expect(response.status).to eq(200)

        json = response.parsed_body

        expect(json["user"]["associated_accounts"]).to eq(nil) # Not serialized in card
        expect(json["user"]["username"]).to eq(user.username)
      end

      it "returns not found when the username doesn't exist" do
        get "/u/madeuppity/card.json"
        expect(response).not_to be_successful
      end

      it "returns partial response when inactive user" do
        user.update!(active: false)
        get "/u/#{user.username}/card.json"
        expect(response).to be_successful
        expect(response.parsed_body["user"]["inactive"]).to eq(true)
      end

      it "raises an error on invalid access" do
        Guardian.any_instance.expects(:can_see?).with(user).returns(false)
        get "/u/#{user.username}/card.json"
        expect(response).to be_forbidden
      end

      context "when hidden users" do
        before { user.user_option.update!(hide_profile: true) }

        it "returns the correct partial response when the user has messages enabled" do
          user.user_option.update!(allow_private_messages: true)
          get "/u/#{user.username}/card.json"
          expect(response).to be_successful
          expect(response.parsed_body["user"]["profile_hidden"]).to eq(true)
          expect(response.parsed_body["user"]["can_send_private_message_to_user"]).to eq(true)
        end

        it "returns the correct partial response when the user has messages disabled" do
          user.user_option.update!(allow_private_messages: false)
          get "/u/#{user.username}/card.json"
          expect(response).to be_successful
          expect(response.parsed_body["user"]["profile_hidden"]).to eq(true)
          expect(response.parsed_body["user"]["can_send_private_message_to_user"]).to eq(false)
        end
      end
    end
  end

  describe "#cards" do
    fab!(:user) { Discourse.system_user }
    fab!(:user2) { Fabricate(:user) }

    it "returns success" do
      get "/user-cards.json?user_ids=#{user.id},#{user2.id}"
      expect(response.status).to eq(200)
      parsed = response.parsed_body["users"]

      expect(parsed.map { |u| u["username"] }).to contain_exactly(user.username, user2.username)
    end

    it "should have http status 403 for anonymous user when profiles are hidden" do
      SiteSetting.hide_user_profiles_from_public = true
      get "/user-cards.json?user_ids=#{user.id},#{user2.id}"
      expect(response).to have_http_status(:forbidden)
    end

    context "when `hide_profile` user option is checked" do
      before { user2.user_option.update_columns(hide_profile: true) }

      it "does not include hidden profiles" do
        get "/user-cards.json?user_ids=#{user.id},#{user2.id}"
        expect(response.status).to eq(200)
        parsed = response.parsed_body["users"]

        expect(parsed.map { |u| u["username"] }).to contain_exactly(user.username)
      end

      it "does include hidden profiles when `allow_users_to_hide_profile` is false" do
        SiteSetting.allow_users_to_hide_profile = false

        get "/user-cards.json?user_ids=#{user.id},#{user2.id}"
        expect(response.status).to eq(200)
        parsed = response.parsed_body["users"]

        expect(parsed.map { |u| u["username"] }).to contain_exactly(user.username, user2.username)
      end
    end
  end

  describe "#badges" do
    it "renders fine by default" do
      get "/u/#{user1.username}/badges"
      expect(response.status).to eq(200)
    end

    it "fails if badges are disabled" do
      SiteSetting.enable_badges = false
      get "/u/#{user1.username}/badges"
      expect(response.status).to eq(404)
    end
  end

  describe "#account_created" do
    it "returns a message when no session is present" do
      get "/u/account-created"

      expect(response.status).to eq(200)

      body = response.body

      expect(body).to match(I18n.t("activation.missing_session"))
    end

    it "redirects when the user is logged in" do
      sign_in(user1)

      get "/u/account-created"

      expect(response).to redirect_to("/")
    end

    context "when cookies contains a destination URL" do
      it "should redirect to the URL" do
        sign_in(user1)

        destination_url = "http://thisisasite.com/somepath"
        cookies[:destination_url] = destination_url

        get "/u/account-created"

        expect(response).to redirect_to(destination_url)
      end
    end

    context "when the user account is created" do
      include ApplicationHelper

      it "returns the message when set in the session" do
        user1 = create_user
        get "/u/account-created"

        expect(response.status).to eq(200)

        expect(response.body).to have_tag("div#data-preloaded") do |element|
          json = JSON.parse(element.current_scope.attribute("data-preloaded").value)
          expect(json["accountCreated"]).to include(
            "{\"message\":\"#{I18n.t("login.activate_email", email: user1.email).gsub!("</", "<\\/")}\",\"show_controls\":true,\"username\":\"#{user1.username}\",\"email\":\"#{user1.email}\"}",
          )
        end
      end
    end
  end

  describe "#search_users" do
    fab!(:topic)
    let(:user) { Fabricate :user, username: "joecabot", name: "Lawrence Tierney" }
    let(:post1) { Fabricate(:post, user: user, topic: topic) }
    let(:staged_user) { Fabricate(:user, staged: true) }

    before do
      SearchIndexer.enable
      post1
    end

    it "searches when provided the term only" do
      get "/u/search/users.json", params: { term: user.name.split(" ").last }
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["users"].map { |u| u["username"] }).to include(user.username)
    end

    context "when searching usernames" do
      it "searches when provided a list of usernames" do
        users = Fabricate.times(3, :user)

        get "/u/search/users.json", params: { usernames: users.map(&:username).join(",") }
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["users"].map { |u| u["username"] }).to match_array(users.map(&:username))
      end

      it "searches groups if include_groups = true" do
        users = Fabricate.times(3, :user)
        group = Fabricate(:group)

        sign_in(user)

        get "/u/search/users.json",
            params: {
              usernames: [group.name, users.first.username].join(","),
              include_groups: true,
            }
        expect(response.status).to eq(200)
        json = response.parsed_body

        expect(json["users"].map { |u| u["username"] }).to contain_exactly(users.first.username)
        expect(json["groups"].map { |u| u["name"] }).to contain_exactly(group.name)
      end
    end

    it "searches when provided the topic only" do
      get "/u/search/users.json", params: { topic_id: topic.id }
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["users"].map { |u| u["username"] }).to include(user.username)
    end

    it "searches when provided the term and topic" do
      get "/u/search/users.json", params: { term: user.name.split(" ").last, topic_id: topic.id }

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["users"].map { |u| u["username"] }).to include(user.username)
    end

    it "searches only for users who have access to private topic" do
      searching_user = Fabricate(:user)
      privileged_user =
        Fabricate(:user, trust_level: 4, username: "joecabit", name: "Lawrence Tierney")
      privileged_group = Fabricate(:group)
      privileged_group.add(searching_user)
      privileged_group.add(privileged_user)
      privileged_group.save

      category = Fabricate(:category)
      category.set_permissions(privileged_group => :readonly)
      category.save

      private_topic = Fabricate(:topic, category: category)

      sign_in(searching_user)
      get "/u/search/users.json",
          params: {
            term: user.name.split(" ").last,
            topic_id: private_topic.id,
            topic_allowed_users: "true",
          }

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["users"].map { |u| u["username"] }).to_not include(user.username)
      expect(json["users"].map { |u| u["username"] }).to include(privileged_user.username)
    end

    it "interprets blank category id correctly" do
      pm_topic = Fabricate(:private_message_post).topic
      sign_in(pm_topic.user)
      get "/u/search/users.json", params: { term: "", topic_id: pm_topic.id, category_id: "" }
      expect(response.status).to eq(200)
    end

    describe "when limit params is invalid" do
      include_examples "invalid limit params",
                       "/u/search/users.json",
                       described_class::SEARCH_USERS_LIMIT
    end

    context "when `enable_names` is true" do
      before { SiteSetting.enable_names = true }

      it "returns names" do
        get "/u/search/users.json", params: { term: user.name }
        json = response.parsed_body
        expect(json["users"].map { |u| u["name"] }).to include(user.name)
      end
    end

    context "when `enable_names` is false" do
      before { SiteSetting.enable_names = false }

      it "returns names" do
        get "/u/search/users.json", params: { term: user.name }
        json = response.parsed_body
        expect(json["users"].map { |u| u["name"] }).not_to include(user.name)
      end
    end

    context "with groups" do
      fab!(:mentionable_group) do
        Fabricate(
          :group,
          mentionable_level: Group::ALIAS_LEVELS[:everyone],
          messageable_level: Group::ALIAS_LEVELS[:nobody],
          visibility_level: Group.visibility_levels[:public],
          name: "aaa1bbb",
        )
      end

      fab!(:mentionable_group_2) do
        Fabricate(
          :group,
          mentionable_level: Group::ALIAS_LEVELS[:everyone],
          messageable_level: Group::ALIAS_LEVELS[:nobody],
          visibility_level: Group.visibility_levels[:logged_on_users],
          name: "bbb1aaa",
        )
      end

      fab!(:messageable_group) do
        Fabricate(
          :group,
          mentionable_level: Group::ALIAS_LEVELS[:nobody],
          messageable_level: Group::ALIAS_LEVELS[:everyone],
          visibility_level: Group.visibility_levels[:logged_on_users],
          name: "ccc1aaa",
        )
      end

      fab!(:private_group) do
        Fabricate(
          :group,
          mentionable_level: Group::ALIAS_LEVELS[:members_mods_and_admins],
          messageable_level: Group::ALIAS_LEVELS[:members_mods_and_admins],
          visibility_level: Group.visibility_levels[:members],
          name: "ddd1aaa",
        )
      end

      describe "when signed in" do
        before { sign_in(user) }

        it "correctly sorts on prefix" do
          get "/u/search/users.json", params: { include_groups: "true", term: "bbb" }

          expect(response.status).to eq(200)
          groups = response.parsed_body["groups"]

          expect(groups.map { |g| g["name"] }).to eq(%w[bbb1aaa aaa1bbb])
        end

        it "does not search for groups if there is no term" do
          get "/u/search/users.json", params: { include_groups: "true" }

          expect(response.status).to eq(200)

          groups = response.parsed_body["groups"]
          expect(groups).to eq(nil)
        end

        it "only returns visible groups" do
          get "/u/search/users.json", params: { include_groups: "true", term: "a" }

          expect(response.status).to eq(200)

          groups = response.parsed_body["groups"]

          expect(groups.map { |group| group["name"] }).to_not include(private_group.name)
        end

        it "allows plugins to register custom groups filter" do
          get "/u/search/users.json", params: { include_groups: "true", term: "a" }

          expect(response.status).to eq(200)
          groups = response.parsed_body["groups"]
          expect(groups.count).to eq(6)

          plugin = Plugin::Instance.new
          plugin.register_groups_callback_for_users_search_controller_action(
            :admins_filter,
          ) { |original_groups, user| original_groups.where(name: "admins") }
          get "/u/search/users.json",
              params: {
                include_groups: "true",
                admins_filter: "true",
                term: "a",
              }
          expect(response.status).to eq(200)
          groups = response.parsed_body["groups"]
          expect(groups).to eq([{ "name" => "admins", "full_name" => nil }])

          DiscoursePluginRegistry.reset!
        end

        it "allows plugins to use apply modifiers to the groups filter" do
          get "/u/search/users.json", params: { include_groups: "true", term: "a" }

          expect(response.status).to eq(200)
          initial_groups = response.parsed_body["groups"]
          expect(initial_groups.count).to eq(6)

          Plugin::Instance
            .new
            .register_modifier(:groups_for_users_search) do |groups|
              groups.where(name: initial_groups.first["name"])
            end

          get "/u/search/users.json", params: { include_groups: "true", term: "a" }
          expect(response.status).to eq(200)
          expect(response.parsed_body["groups"].count).to eq(1)

          DiscoursePluginRegistry.reset!
        end

        it "works when the modifier to the groups filter introduces a join with a conflicting name fields like `id` for example" do
          %i[
            include_groups
            include_mentionable_groups
            include_messageable_groups
          ].each do |param_name|
            get "/u/search/users.json", params: { param_name => "true", :term => "a" }

            expect(response.status).to eq(200)

            Plugin::Instance
              .new
              .register_modifier(:groups_for_users_search) do |groups|
                # a join with a conflicting name field (id) is introduced here
                # we expect the query to work correctly
                groups.left_joins(:users).where(users: { admin: true })
              end

            get "/u/search/users.json", params: { param_name => "true", :term => "a" }
            expect(response.status).to eq(200) # the conflict would cause a 500 error

            DiscoursePluginRegistry.reset!
          end
        end

        it "doesn't search for groups" do
          get "/u/search/users.json",
              params: {
                include_mentionable_groups: "false",
                include_messageable_groups: "false",
                term: "a",
              }

          expect(response.status).to eq(200)
          expect(response.parsed_body).not_to have_key(:groups)
        end

        it "searches for messageable groups" do
          get "/u/search/users.json",
              params: {
                include_mentionable_groups: "false",
                include_messageable_groups: "true",
                term: "a",
              }

          expect(response.status).to eq(200)

          expect(response.parsed_body["groups"].map { |group| group["name"] }).to contain_exactly(
            messageable_group.name,
            Group.find(Group::AUTO_GROUPS[:moderators]).name,
          )
        end

        it "searches for mentionable groups" do
          get "/u/search/users.json",
              params: {
                include_messageable_groups: "false",
                include_mentionable_groups: "true",
                term: "a",
              }

          expect(response.status).to eq(200)

          groups = response.parsed_body["groups"]

          expect(groups.map { |group| group["name"] }).to contain_exactly(
            mentionable_group.name,
            mentionable_group_2.name,
          )
        end
      end

      describe "when not signed in" do
        it "should not include mentionable/messageable groups" do
          get "/u/search/users.json",
              params: {
                include_mentionable_groups: "false",
                include_messageable_groups: "false",
                term: "a",
              }

          expect(response.status).to eq(200)
          expect(response.parsed_body).not_to have_key(:groups)

          get "/u/search/users.json",
              params: {
                include_mentionable_groups: "false",
                include_messageable_groups: "true",
                term: "a",
              }

          expect(response.status).to eq(200)
          expect(response.parsed_body).not_to have_key(:groups)

          get "/u/search/users.json",
              params: {
                include_messageable_groups: "false",
                include_mentionable_groups: "true",
                term: "a",
              }

          expect(response.status).to eq(200)
          expect(response.parsed_body).not_to have_key(:groups)
        end
      end

      describe "when searching by group name" do
        fab!(:exclusive_group) { Fabricate(:group) }

        it "return results if the user is a group member" do
          exclusive_group.add(user)

          get "/u/search/users.json", params: { group: exclusive_group.name, term: user.username }

          expect(users_found).to contain_exactly(user.username)
        end

        it "does not return results if the user is not a group member" do
          get "/u/search/users.json", params: { group: exclusive_group.name, term: user.username }

          expect(users_found).to be_empty
        end

        it "returns results if the user is member of one of the groups" do
          exclusive_group.add(user)

          get "/u/search/users.json",
              params: {
                groups: [exclusive_group.name],
                term: user.username,
              }

          expect(users_found).to contain_exactly(user.username)
        end

        it "does not return results if the user is not a member of the groups" do
          get "/u/search/users.json",
              params: {
                groups: [exclusive_group.name],
                term: user.username,
              }

          expect(users_found).to be_empty
        end

        def users_found
          response.parsed_body["users"].map { |u| u["username"] }
        end
      end
    end

    context "with `include_staged_users`" do
      it "includes staged users when the param is true" do
        get "/u/search/users.json", params: { term: staged_user.name, include_staged_users: true }
        json = response.parsed_body
        expect(json["users"].map { |u| u["name"] }).to include(staged_user.name)
      end

      it "doesn't include staged users when the param is not passed" do
        get "/u/search/users.json", params: { term: staged_user.name }
        json = response.parsed_body
        expect(json["users"].map { |u| u["name"] }).not_to include(staged_user.name)
      end

      it "doesn't include staged users when the param explicitly set to false" do
        get "/u/search/users.json", params: { term: staged_user.name, include_staged_users: false }
        json = response.parsed_body
        expect(json["users"].map { |u| u["name"] }).not_to include(staged_user.name)
      end
    end

    context "with `last_seen_users`" do
      it "returns results when the param is true" do
        get "/u/search/users.json", params: { last_seen_users: true }

        json = response.parsed_body
        expect(json["users"]).not_to be_empty
      end

      it "respects limit parameter at the same time" do
        limit = 3
        get "/u/search/users.json", params: { last_seen_users: true, limit: limit }

        json = response.parsed_body
        expect(json["users"]).not_to be_empty
        expect(json["users"].size).to eq(limit)
      end
    end

    it "returns avatar_template" do
      get "/u/search/users.json", params: { term: user.username }
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["users"][0]).to have_key("avatar_template")
      expect(json["users"][0]["avatar_template"]).to eq(
        "/letter_avatar_proxy/v4/letter/j/f475e1/{size}.png",
      )
    end

    describe "#status" do
      it "returns user status if enabled in site settings" do
        SiteSetting.enable_user_status = true
        emoji = "tooth"
        description = "off to dentist"
        user.set_status!(description, emoji)

        get "/u/search/users.json", params: { term: user.name }

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["users"][0]).to have_key("status")
        expect(json["users"][0]["status"]["description"]).to eq(description)
        expect(json["users"][0]["status"]["emoji"]).to eq(emoji)
      end

      it "doesn't return user status if disabled in site settings" do
        SiteSetting.enable_user_status = false
        user.set_status!("off to dentist", "tooth")

        get "/u/search/users.json", params: { term: user.name }

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["users"][0]).not_to have_key("status")
      end
    end
  end

  describe "#email_login" do
    before { SiteSetting.enable_local_logins_via_email = true }

    it "enqueues the right email" do
      post "/u/email-login.json", params: { login: user1.email }

      expect(response.status).to eq(200)
      expect(response.parsed_body["user_found"]).to eq(true)

      job_args = Jobs::CriticalUserEmail.jobs.last["args"].first
      expect(job_args["user_id"]).to eq(user1.id)
      expect(job_args["type"]).to eq("email_login")
      expect(EmailToken.hash_token(job_args["email_token"])).to eq(
        user1.email_tokens.last.token_hash,
      )
    end

    describe "when enable_local_logins_via_email is disabled" do
      before { SiteSetting.enable_local_logins_via_email = false }

      it "should return the right response" do
        post "/u/email-login.json", params: { login: user1.email }
        expect(response.status).to eq(404)
      end
    end

    describe "when username or email is not valid" do
      it "should not enqueue the email to login" do
        post "/u/email-login.json", params: { login: "@random" }

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["user_found"]).to eq(false)
        expect(json["hide_taken"]).to eq(false)
        expect(Jobs::CriticalUserEmail.jobs).to eq([])
      end
    end

    describe "when hide_email_address_taken is true" do
      it "should return the right response" do
        SiteSetting.hide_email_address_taken = true
        post "/u/email-login.json", params: { login: user1.email }

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json.has_key?("user_found")).to eq(false)
        expect(json["hide_taken"]).to eq(true)
      end
    end

    describe "when user is already logged in" do
      it "should redirect to the root path" do
        sign_in(user1)
        post "/u/email-login.json", params: { login: user1.email }

        expect(response).to redirect_to("/")
      end
    end
  end

  describe "#create_second_factor_totp" do
    context "when not logged in" do
      it "should return the right response" do
        post "/users/second_factors.json", params: { password: "wrongpassword" }

        expect(response.status).to eq(403)
      end
    end

    context "when logged in" do
      before { sign_in(user1) }

      describe "create 2fa request" do
        it "fails on incorrect password" do
          ApplicationController
            .any_instance
            .expects(:secure_session)
            .returns("confirmed-session-#{user1.id}" => "false")
          post "/users/create_second_factor_totp.json"

          expect(response.status).to eq(403)
        end

        describe "when local logins are disabled" do
          it "should return the right response" do
            SiteSetting.enable_local_logins = false

            post "/users/create_second_factor_totp.json"

            expect(response.status).to eq(404)
          end
        end

        describe "when SSO is enabled" do
          it "should return the right response" do
            SiteSetting.discourse_connect_url = "http://someurl.com"
            SiteSetting.enable_discourse_connect = true

            post "/users/create_second_factor_totp.json"

            expect(response.status).to eq(404)
          end
        end

        it "succeeds on correct password" do
          ApplicationController
            .any_instance
            .stubs(:secure_session)
            .returns("confirmed-session-#{user1.id}" => "true")
          post "/users/create_second_factor_totp.json"

          expect(response.status).to eq(200)

          response_body = response.parsed_body

          expect(response_body["key"]).to be_present
          expect(response_body["qr"]).to be_present
        end

        it "raises an error for a user created > 5 mins ago without a confirmed session" do
          post "/users/create_second_factor_totp.json"

          expect(response.status).to eq(403)
        end

        it "does not require confirming session for a user created < 5 mins ago" do
          user1.update(created_at: Time.now.utc - 4.minutes)
          post "/users/create_second_factor_totp.json"

          expect(response.status).to eq(200)
        end
      end
    end
  end

  describe "#enable_second_factor_totp" do
    before { sign_in(user1) }

    def create_totp
      stub_secure_session_confirmed
      post "/users/create_second_factor_totp.json"
    end

    it "creates a totp for the user successfully" do
      create_totp
      staged_totp_key = read_secure_session["staged-totp-#{user1.id}"]
      token = ROTP::TOTP.new(staged_totp_key).now

      post "/users/enable_second_factor_totp.json",
           params: {
             name: "test",
             second_factor_token: token,
           }

      expect(response.status).to eq(200)
      expect(user1.user_second_factors.count).to eq(1)
    end

    it "rate limits by IP address" do
      RateLimiter.enable

      create_totp
      staged_totp_key = read_secure_session["staged-totp-#{user1.id}"]
      token = ROTP::TOTP.new(staged_totp_key).now

      7.times do |x|
        post "/users/enable_second_factor_totp.json",
             params: {
               name: "test",
               second_factor_token: token,
             }
      end

      expect(response.status).to eq(429)
    end

    it "rate limits by username" do
      RateLimiter.enable

      create_totp
      staged_totp_key = read_secure_session["staged-totp-#{user1.id}"]
      token = ROTP::TOTP.new(staged_totp_key).now

      7.times do |x|
        post "/users/enable_second_factor_totp.json",
             params: {
               name: "test",
               second_factor_token: token,
             },
             env: {
               REMOTE_ADDR: "1.2.3.#{x}",
             }
      end

      expect(response.status).to eq(429)
    end

    context "when an incorrect token is provided" do
      before do
        create_totp
        post "/users/enable_second_factor_totp.json",
             params: {
               name: "test",
               second_factor_token: "123456",
             }
      end
      it "shows a helpful error message to the user" do
        expect(response.parsed_body["error"]).to eq(I18n.t("login.invalid_second_factor_code"))
      end
    end

    context "when a name is not provided" do
      before do
        create_totp
        post "/users/enable_second_factor_totp.json", params: { second_factor_token: "123456" }
      end
      it "shows a helpful error message to the user" do
        expect(response.parsed_body["error"]).to eq(I18n.t("login.missing_second_factor_name"))
      end
    end

    context "when a token is not provided" do
      before do
        create_totp
        post "/users/enable_second_factor_totp.json", params: { name: "test" }
      end
      it "shows a helpful error message to the user" do
        expect(response.parsed_body["error"]).to eq(I18n.t("login.missing_second_factor_code"))
      end
    end

    it "doesn't allow creating too many TOTPs" do
      Fabricate(:user_second_factor_totp, user: user1)

      create_totp
      staged_totp_key = read_secure_session["staged-totp-#{user1.id}"]
      token = ROTP::TOTP.new(staged_totp_key).now

      stub_const(UserSecondFactor, "MAX_TOTPS_PER_USER", 1) do
        post "/users/enable_second_factor_totp.json",
             params: {
               name: "test",
               second_factor_token: token,
             }
      end

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to include(I18n.t("login.too_many_authenticators"))

      expect(user1.user_second_factors.count).to eq(1)
    end

    it "doesn't allow the TOTP name to exceed the limit" do
      create_totp
      staged_totp_key = read_secure_session["staged-totp-#{user1.id}"]
      token = ROTP::TOTP.new(staged_totp_key).now

      post "/users/enable_second_factor_totp.json",
           params: {
             name: "a" * (UserSecondFactor::MAX_NAME_LENGTH + 1),
             second_factor_token: token,
           }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to include(
        "Name is too long (maximum is 300 characters)",
      )

      expect(user1.user_second_factors.count).to eq(0)
    end
  end

  describe "#update_second_factor" do
    fab!(:user_second_factor) { Fabricate(:user_second_factor_totp, user: user1) }

    context "when not logged in" do
      it "should return the right response" do
        put "/users/second_factor.json"

        expect(response.status).to eq(403)
      end
    end

    context "when logged in" do
      before { sign_in(user1) }

      context "when user has totp setup" do
        context "when token is missing" do
          it "returns the right response" do
            put "/users/second_factor.json",
                params: {
                  disable: "true",
                  second_factor_target: UserSecondFactor.methods[:totp],
                  id: user_second_factor.id,
                }

            expect(response.status).to eq(403)
          end
        end

        context "when token is valid" do
          before { stub_secure_session_confirmed }
          it "should allow second factor for the user to be renamed" do
            put "/users/second_factor.json",
                params: {
                  name: "renamed",
                  second_factor_target: UserSecondFactor.methods[:totp],
                  id: user_second_factor.id,
                }

            expect(response.status).to eq(200)
            expect(user1.reload.user_second_factors.totps.first.name).to eq("renamed")
          end

          it "should allow second factor for the user to be disabled" do
            put "/users/second_factor.json",
                params: {
                  disable: "true",
                  second_factor_target: UserSecondFactor.methods[:totp],
                  id: user_second_factor.id,
                }

            expect(response.status).to eq(200)
            expect(user1.reload.user_second_factors.totps.first).to eq(nil)
          end
        end
      end

      context "when user is updating backup codes" do
        context "when token is missing" do
          it "returns the right response" do
            put "/users/second_factor.json",
                params: {
                  second_factor_target: UserSecondFactor.methods[:backup_codes],
                }

            expect(response.status).to eq(403)
          end
        end

        context "when token is valid" do
          before do
            ApplicationController
              .any_instance
              .stubs(:secure_session)
              .returns("confirmed-session-#{user1.id}" => "true")
          end
          it "should allow second factor backup for the user to be disabled" do
            put "/users/second_factor.json",
                params: {
                  second_factor_target: UserSecondFactor.methods[:backup_codes],
                  disable: "true",
                }

            expect(response.status).to eq(200)
            expect(user1.reload.user_second_factors.backup_codes).to be_empty
          end
        end
      end
    end
  end

  describe "#create_second_factor_backup" do
    fab!(:user_second_factor) { Fabricate(:user_second_factor_totp, user: user1) }

    context "when not logged in" do
      it "should return the right response" do
        put "/users/second_factors_backup.json",
            params: {
              second_factor_token: "wrongtoken",
              second_factor_method: UserSecondFactor.methods[:totp],
            }

        expect(response.status).to eq(403)
      end
    end

    context "when logged in" do
      before { sign_in(user1) }

      describe "create 2fa request" do
        it "fails on incorrect password" do
          ApplicationController
            .any_instance
            .expects(:secure_session)
            .returns("confirmed-session-#{user1.id}" => "false")
          put "/users/second_factors_backup.json"

          expect(response.status).to eq(403)
        end

        describe "when local logins are disabled" do
          it "should return the right response" do
            SiteSetting.enable_local_logins = false

            put "/users/second_factors_backup.json"

            expect(response.status).to eq(404)
          end
        end

        describe "when SSO is enabled" do
          it "should return the right response" do
            SiteSetting.discourse_connect_url = "http://someurl.com"
            SiteSetting.enable_discourse_connect = true

            put "/users/second_factors_backup.json"

            expect(response.status).to eq(404)
          end
        end

        it "succeeds on correct password" do
          ApplicationController
            .any_instance
            .expects(:secure_session)
            .returns("confirmed-session-#{user1.id}" => "true")

          put "/users/second_factors_backup.json"

          expect(response.status).to eq(200)

          response_body = response.parsed_body

          # we use SecureRandom.hex(16) for backup codes, ensure this continues to be the case
          expect(response_body["backup_codes"].map(&:length)).to eq([32] * 10)
        end
      end
    end
  end

  describe "#create_second_factor_security_key" do
    it "stores the challenge in the session and returns challenge data, user id, and supported algorithms" do
      create_second_factor_security_key
      secure_session = read_secure_session
      response_parsed = response.parsed_body
      expect(response_parsed["challenge"]).to eq(DiscourseWebauthn.challenge(user1, secure_session))
      expect(response_parsed["rp_id"]).to eq(DiscourseWebauthn.rp_id)
      expect(response_parsed["rp_name"]).to eq(DiscourseWebauthn.rp_name)
      expect(response_parsed["user_secure_id"]).to eq(
        user1.reload.create_or_fetch_secure_identifier,
      )
      expect(response_parsed["supported_algorithms"]).to eq(
        ::DiscourseWebauthn::SUPPORTED_ALGORITHMS,
      )
    end

    it "doesn't create a challenge if the user has the maximum number allowed of security keys" do
      Fabricate(:user_security_key_with_random_credential, user: user1)
      stub_const(UserSecurityKey, "MAX_KEYS_PER_USER", 1) { create_second_factor_security_key }
      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to include(I18n.t("login.too_many_security_keys"))
    end

    context "if the user has security key credentials already" do
      fab!(:user_security_key) { Fabricate(:user_security_key_with_random_credential, user: user1) }

      it "returns those existing active credentials" do
        create_second_factor_security_key
        response_parsed = response.parsed_body
        expect(response_parsed["existing_active_credential_ids"]).to eq(
          [user_security_key.credential_id],
        )
      end
    end
  end

  describe "#register_second_factor_security_key" do
    before do
      simulate_localhost_webauthn_challenge
      DiscourseWebauthn.stubs(:origin).returns("http://localhost:3000")
    end

    context "when creation parameters are valid" do
      it "creates a security key for the user" do
        create_second_factor_security_key
        _response_parsed = response.parsed_body

        post "/u/register_second_factor_security_key.json",
             params: valid_security_key_create_post_data

        expect(user1.security_keys.count).to eq(1)
        expect(user1.security_keys.last.credential_id).to eq(
          valid_security_key_create_post_data[:rawId],
        )
        expect(user1.security_keys.last.name).to eq(valid_security_key_create_post_data[:name])
      end

      it "doesn't allow creating too many security keys" do
        create_second_factor_security_key
        _response_parsed = response.parsed_body

        Fabricate(:user_security_key_with_random_credential, user: user1)

        stub_const(UserSecurityKey, "MAX_KEYS_PER_USER", 1) do
          post "/u/register_second_factor_security_key.json",
               params: valid_security_key_create_post_data
        end

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to include(I18n.t("login.too_many_security_keys"))

        expect(user1.security_keys.count).to eq(1)
      end

      it "doesn't allow the security key name to exceed the limit" do
        create_second_factor_security_key
        _response_parsed = response.parsed_body

        post "/u/register_second_factor_security_key.json",
             params:
               valid_security_key_create_post_data.merge(
                 name: "a" * (UserSecurityKey::MAX_NAME_LENGTH + 1),
               )

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to include(
          "Name is too long (maximum is 300 characters)",
        )

        expect(user1.security_keys.count).to eq(0)
      end
    end

    context "when the creation parameters are invalid" do
      it "shows a security key error and does not create a key" do
        create_second_factor_security_key
        _response_parsed = response.parsed_body

        post "/u/register_second_factor_security_key.json",
             params: {
               id: "bad id",
               rawId: "bad rawId",
               type: "public-key",
               attestation: "bad attestation",
               clientData: Base64.encode64('{"bad": "json"}'),
               name: "My Bad Key",
             }

        expect(user1.security_keys.count).to eq(0)
        expect(response.parsed_body["error"]).to eq(
          I18n.t("webauthn.validation.invalid_type_error"),
        )
      end
    end
  end

  describe "#disable_second_factor" do
    context "when logged in with secure session" do
      before do
        sign_in(user1)
        stub_secure_session_confirmed
      end

      context "when user has a registered totp and security key" do
        before do
          _totp_second_factor = Fabricate(:user_second_factor_totp, user: user1)
          _security_key_second_factor =
            Fabricate(
              :user_security_key,
              user: user1,
              factor_type: UserSecurityKey.factor_types[:second_factor],
            )
          Fabricate(:passkey_with_random_credential, user: user1)
        end

        it "should disable all totp and security keys (but not passkeys)" do
          expect_enqueued_with(
            job: :critical_user_email,
            args: {
              type: :account_second_factor_disabled,
              user_id: user1.id,
            },
          ) do
            put "/u/disable_second_factor.json"

            expect(response.status).to eq(200)

            expect(user1.reload.user_second_factors).to be_empty
            expect(user1.second_factor_security_keys).to be_empty
            expect(user1.security_keys.length).to eq(1)
            expect(user1.security_keys[0].factor_type).to eq(
              UserSecurityKey.factor_types[:first_factor],
            )
            expect(user1.passkey_credential_ids.length).to eq(1)
          end
        end
      end
    end
  end

  describe "#create_passkey" do
    before do
      SiteSetting.enable_passkeys = true
      stub_secure_session_confirmed
    end

    it "fails if user is not logged in" do
      post "/u/create_passkey.json"

      expect(response.status).to eq(403)
    end

    it "stores the challenge in the session and returns challenge data, user id, and supported algorithms" do
      sign_in(user1)
      post "/u/create_passkey.json"

      secure_session = read_secure_session
      response_parsed = response.parsed_body
      expect(response_parsed["challenge"]).to eq(DiscourseWebauthn.challenge(user1, secure_session))
      expect(response_parsed["rp_id"]).to eq(DiscourseWebauthn.rp_id)
      expect(response_parsed["rp_name"]).to eq(DiscourseWebauthn.rp_name)
      expect(response_parsed["user_secure_id"]).to eq(user1.reload.secure_identifier)
      expect(response_parsed["supported_algorithms"]).to eq(
        ::DiscourseWebauthn::SUPPORTED_ALGORITHMS,
      )
    end

    context "when user has a passkey" do
      fab!(:user_security_key) { Fabricate(:passkey_with_random_credential, user: user1) }

      it "returns existing active credentials" do
        sign_in(user1)
        post "/u/create_passkey.json"

        response_parsed = response.parsed_body
        expect(response_parsed["existing_passkey_credential_ids"]).to eq(
          [user_security_key.credential_id],
        )
      end
    end
  end

  describe "#rename_passkey" do
    before { SiteSetting.enable_passkeys = true }

    it "fails if no user is logged in" do
      put "/u/rename_passkey/NONE.json"

      expect(response.status).to eq(403)
    end

    it "fails if no name parameter is provided" do
      sign_in(user1)
      put "/u/rename_passkey/ID.json"

      expect(response.status).to eq(400)
      expect(response.parsed_body["errors"][0]).to eq(
        "param is missing or the value is empty: name",
      )
    end

    it "fails if key is invalid" do
      sign_in(user1)
      put "/u/rename_passkey/ID.json", params: { name: "new name" }

      expect(response.status).to eq(400)
      expect(response.parsed_body["errors"][0]).to include(
        "You supplied invalid parameters to the request: id",
      )
    end

    context "with an existing passkey" do
      fab!(:passkey) do
        Fabricate(:passkey_with_random_credential, user: user1, name: "original name")
      end

      it "renames the key" do
        sign_in(user1)
        put "/u/rename_passkey/#{passkey.id}.json", params: { name: "new name" }
        response_parsed = response.parsed_body

        expect(response.status).to eq(200)
        expect(passkey.reload.name).to eq("new name")
      end

      it "does not let an admin delete a passkey associated with user1" do
        sign_in(admin)

        put "/u/rename_passkey/#{passkey.id}.json", params: { name: "new name" }

        expect(passkey.reload.name).to eq("original name")
      end
    end
  end

  describe "#delete_passkey" do
    before { SiteSetting.enable_passkeys = true }
    fab!(:passkey) { Fabricate(:passkey_with_random_credential, user: user1) }

    it "fails if user does not have a confirmed session" do
      sign_in(user1)
      delete "/u/delete_passkey/#{passkey.id}.json"
      expect(response.status).to eq(403)
    end

    context "with a confirmed session" do
      before { stub_secure_session_confirmed }

      it "fails if user is not logged in" do
        delete "/u/delete_passkey/#{passkey.id}.json"
        expect(response.status).to eq(403)
      end

      it "deletes the key" do
        sign_in(user1)
        delete "/u/delete_passkey/#{passkey.id}.json"
        expect(response.status).to eq(200)
        expect(user1.passkey_credential_ids).to eq([])
      end

      it "does not let an admin delete a passkey associated with user1" do
        sign_in(admin)
        delete "/u/delete_passkey/#{passkey.id}.json"
        expect(response.status).to eq(200)

        expect(user1.passkey_credential_ids[0]).to eq(passkey.credential_id)
      end
    end
  end

  describe "#register_passkey" do
    before do
      SiteSetting.enable_passkeys = true
      DiscourseWebauthn.stubs(:origin).returns("http://localhost:3000")
    end

    it "fails if user is not logged in" do
      stub_secure_session_confirmed
      post "/u/register_passkey.json"

      expect(response.status).to eq(403)
    end

    it "fails if session is not confirmed" do
      sign_in(user1)
      post "/u/register_passkey.json"
      expect(response.status).to eq(403)
    end

    context "with a valid key" do
      let(:attestation) do
        "o2NmbXRkbm9uZWdhdHRTdG10oGhhdXRoRGF0YVikSZYN5YgOjGh0NBcPZHZgW4/krrmihjLHmVzzuoMdl2NFAAAAAK3OAAI1vMYKZIsLJfHwVQMAICRXq4sFZ9XpWZOzfJ8EguJmoEPMzNVyFMUWQfT5u1QzpQECAyYgASFYILjOiAHAwNrXkCk/tmyYRiE87QyV/15wUvhcXhr1JfwtIlggClQywgQvSxTsqV/FSK0cNHTTmuwfzzREqE6eLDmPxmI="
      end
      let(:valid_client_param) { passkey_client_data_param("webauthn.create") }
      let(:invalid_client_param) { passkey_client_data_param("webauthn.get") }

      before do
        sign_in(user1)
        stub_secure_session_confirmed
        simulate_localhost_passkey_challenge
      end

      it "registers the passkey" do
        post "/u/register_passkey.json",
             params: {
               name: "My Passkey",
               attestation: attestation,
               clientData: Base64.encode64(valid_client_param.to_json),
             }

        expect(response.status).to eq(200)
        expect(response.parsed_body["name"]).to eq("My Passkey")
        expect(user1.passkey_credential_ids).to eq([valid_passkey_data[:credential_id]])
      end

      it "does not register a passkey with the wrong webauthn type" do
        post "/u/register_passkey.json",
             params: {
               name: "My Passkey",
               attestation: attestation,
               clientData: Base64.encode64(invalid_client_param.to_json),
             }

        expect(response.status).to eq(401)
        expect(response.parsed_body["errors"][0]).to eq(
          I18n.t("webauthn.validation.invalid_type_error"),
        )
      end
    end
  end

  describe "#revoke_account" do
    it "errors for unauthorised users" do
      post "/u/#{user1.username}/preferences/revoke-account.json",
           params: {
             provider_name: "facebook",
           }
      expect(response.status).to eq(403)

      sign_in(another_user)

      post "/u/#{user1.username}/preferences/revoke-account.json",
           params: {
             provider_name: "facebook",
           }
      expect(response.status).to eq(403)
    end

    context "while logged in" do
      before { sign_in(user1) }

      it "returns an error when there is no matching account" do
        post "/u/#{user1.username}/preferences/revoke-account.json",
             params: {
               provider_name: "facebook",
             }
        expect(response.status).to eq(404)
      end

      context "with fake provider" do
        let(:authenticator) do
          Class
            .new(Auth::Authenticator) do
              attr_accessor :can_revoke

              def name
                "testprovider"
              end

              def enabled?
                true
              end

              def description_for_user(user)
                "an account"
              end

              def can_revoke?
                can_revoke
              end

              def revoke(user, skip_remote: false)
                true
              end
            end
            .new
        end

        before do
          DiscoursePluginRegistry.register_auth_provider(
            Auth::AuthProvider.new(authenticator: authenticator),
          )
        end

        after { DiscoursePluginRegistry.reset! }

        it "returns an error when revoking is not allowed" do
          authenticator.can_revoke = false

          post "/u/#{user1.username}/preferences/revoke-account.json",
               params: {
                 provider_name: "testprovider",
               }
          expect(response.status).to eq(404)

          authenticator.can_revoke = true
          post "/u/#{user1.username}/preferences/revoke-account.json",
               params: {
                 provider_name: "testprovider",
               }
          expect(response.status).to eq(200)
        end

        it "works" do
          authenticator.can_revoke = true

          post "/u/#{user1.username}/preferences/revoke-account.json",
               params: {
                 provider_name: "testprovider",
               }
          expect(response.status).to eq(200)
        end
      end
    end
  end

  describe "#revoke_auth_token" do
    context "while logged in" do
      before { 2.times { sign_in(user1) } }

      it "logs user out" do
        ids = user1.user_auth_tokens.order(:created_at).pluck(:id)

        post "/u/#{user1.username}/preferences/revoke-auth-token.json", params: { token_id: ids[0] }

        expect(response.status).to eq(200)

        user1.user_auth_tokens.reload
        expect(user1.user_auth_tokens.count).to eq(1)
        expect(user1.user_auth_tokens.first.id).to eq(ids[1])
      end

      it "checks if token exists" do
        ids = user1.user_auth_tokens.order(:created_at).pluck(:id)

        post "/u/#{user1.username}/preferences/revoke-auth-token.json", params: { token_id: ids[0] }

        expect(response.status).to eq(200)

        post "/u/#{user1.username}/preferences/revoke-auth-token.json", params: { token_id: ids[0] }

        expect(response.status).to eq(400)
      end

      it "does not let user log out of current session" do
        token = UserAuthToken.generate!(user_id: user1.id)
        cookie =
          create_auth_cookie(
            token: token.unhashed_auth_token,
            user_id: user1.id,
            trust_level: user1.trust_level,
            issued_at: 5.minutes.ago,
          )

        post "/u/#{user1.username}/preferences/revoke-auth-token.json",
             params: {
               token_id: token.id,
             },
             headers: {
               "HTTP_COOKIE" => "_t=#{cookie}",
             }

        expect(token.reload.id).to be_present
        expect(response.status).to eq(400)
      end

      it "logs user out from everywhere if token_id is not present" do
        post "/u/#{user1.username}/preferences/revoke-auth-token.json"

        expect(response.status).to eq(200)
        expect(user1.user_auth_tokens.count).to eq(0)
      end
    end
  end

  describe "#list_second_factors" do
    let(:user) { user1 }

    before { sign_in(user) }

    context "when SSO is enabled" do
      before do
        SiteSetting.discourse_connect_url = "https://discourse.test/sso"
        SiteSetting.enable_discourse_connect = true
      end

      it "does not allow access" do
        post "/u/second_factors.json"
        expect(response.status).to eq(404)
      end
    end

    context "when local logins are not enabled" do
      before { SiteSetting.enable_local_logins = false }

      it "does not allow access" do
        post "/u/second_factors.json"
        expect(response.status).to eq(404)
      end
    end

    context "when the site settings allow second factors" do
      before do
        SiteSetting.enable_local_logins = true
        SiteSetting.enable_discourse_connect = false
      end

      context "when the session is unconfirmed" do
        it "returns unconfirmed session response" do
          post "/u/second_factors.json"

          expect(response.status).to eq(200)
          response_body = response.parsed_body
          expect(response_body["unconfirmed_session"]).to eq(true)
        end
      end

      context "when the session is confirmed" do
        fab!(:user) { Fabricate(:user, password: "acoolpassword") }

        it "returns a list of enabled totps and security_key second factors" do
          totp_second_factor = Fabricate(:user_second_factor_totp, user: user)
          security_key_second_factor =
            Fabricate(
              :user_security_key,
              user: user,
              factor_type: UserSecurityKey.factor_types[:second_factor],
            )

          post "/u/confirm-session.json", params: { password: "acoolpassword" }

          post "/u/second_factors.json"

          expect(response.status).to eq(200)
          response_body = response.parsed_body
          expect(response_body["totps"].map { |second_factor| second_factor["id"] }).to include(
            totp_second_factor.id,
          )
          expect(
            response_body["security_keys"].map { |second_factor| second_factor["id"] },
          ).to include(security_key_second_factor.id)
        end
      end
    end
  end

  describe "#confirm_session" do
    let(:user) { user1 }
    let(:password) { "test" }

    before { sign_in(user) }

    context "when SSO is enabled" do
      before do
        SiteSetting.discourse_connect_url = "https://discourse.test/sso"
        SiteSetting.enable_discourse_connect = true
      end

      it "does not allow access" do
        post "/u/confirm-session.json", params: { password: password }
        expect(response.status).to eq(404)
      end
    end

    context "when local logins are not enabled" do
      before { SiteSetting.enable_local_logins = false }

      it "does not allow access" do
        post "/u/confirm-session.json", params: { password: password }
        expect(response.status).to eq(404)
      end
    end

    context "when the site settings allow local logins" do
      before do
        SiteSetting.enable_local_logins = true
        SiteSetting.enable_discourse_connect = false
      end

      context "when params are incorrect" do
        it "returns 400 response if no password or passkey is supplied" do
          post "/u/confirm-session.json"

          expect(response.status).to eq(400)
          expect(response.parsed_body["errors"][0]).to include("Missing password or passkey")
        end

        it "returns incorrect response on a wrong password" do
          post "/u/confirm-session.json", params: { password: password }

          expect(response.status).to eq(200)
          expect(response.parsed_body["error"]).to eq("Incorrect password or passkey")
        end
      end

      context "when the password is correct" do
        fab!(:user2) { Fabricate(:user, password: "8555039dd212cc66ec68") }

        it "returns a successful response" do
          sign_in(user2)
          post "/u/confirm-session.json", params: { password: "8555039dd212cc66ec68" }
          expect(response.status).to eq(200)
          expect(response.parsed_body["error"]).to eq(nil)
        end
      end

      context "with an invalid passkey" do
        it "returns invalid response" do
          post "/u/confirm-session.json", params: { publicKeyCredential: "someboringstring" }

          expect(response.status).to eq(401)

          json = response.parsed_body
          expect(json["errors"][0]).to eq(
            I18n.t("webauthn.validation.malformed_public_key_credential_error"),
          )
        end
      end

      context "with a valid passkey" do
        fab!(:user2) { Fabricate(:user) }
        let!(:passkey) do
          Fabricate(
            :user_security_key,
            credential_id: valid_passkey_data[:credential_id],
            public_key: valid_passkey_data[:public_key],
            user: user1,
            factor_type: UserSecurityKey.factor_types[:first_factor],
            last_used: nil,
            name: "passkey",
          )
        end

        before do
          DiscourseWebauthn.stubs(:origin).returns("http://localhost:3000")
          simulate_localhost_passkey_challenge
        end

        it "returns a successful response for the correct user" do
          user1.create_or_fetch_secure_identifier

          post "/u/confirm-session.json",
               params: {
                 publicKeyCredential:
                   valid_passkey_auth_data.merge(
                     { userHandle: Base64.strict_encode64(user1.secure_identifier) },
                   ),
               }

          expect(response.status).to eq(200)
          expect(response.parsed_body["error"]).to eq(nil)
        end

        it "returns invalid response when key belongs to a different user" do
          sign_in(user2)
          user2.create_or_fetch_secure_identifier

          post "/u/confirm-session.json",
               params: {
                 publicKeyCredential:
                   valid_passkey_auth_data.merge(
                     { userHandle: Base64.strict_encode64(user2.secure_identifier) },
                   ),
               }

          expect(response.status).to eq(401)

          json = response.parsed_body
          expect(json["errors"][0]).to eq(I18n.t("webauthn.validation.ownership_error"))
        end
      end
    end
  end

  describe "#trusted_session" do
    it "returns 403 for anons" do
      get "/u/trusted-session.json"
      expect(response.status).to eq(403)
    end

    it "responds with a 'failed' result by default" do
      sign_in(user1)

      get "/u/trusted-session.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["failed"]).to eq("FAILED")
    end

    it "responds with a 'success' result if user was recently created" do
      sign_in(user1)
      user1.update(created_at: Time.now.utc - 4.minutes)

      get "/u/trusted-session.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to eq("OK")
    end

    it "response with 'success' on a confirmed session" do
      user2 = Fabricate(:user, password: "8555039dd212cc66ec68")
      sign_in(user2)

      post "/u/confirm-session.json", params: { password: "8555039dd212cc66ec68" }
      expect(response.status).to eq(200)

      get "/u/trusted-session.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to eq("OK")
    end
  end

  describe "#feature_topic" do
    fab!(:topic)
    fab!(:other_topic) { Fabricate(:topic) }
    fab!(:private_message) { Fabricate(:private_message_topic, user: another_user) }
    fab!(:category) { Fabricate(:category_with_definition) }

    describe "site setting enabled" do
      before { SiteSetting.allow_featured_topic_on_user_profiles = true }

      it "requires the user to be logged in" do
        put "/u/#{user1.username}/feature-topic.json", params: { topic_id: topic.id }
        expect(response.status).to eq(403)
      end

      it "returns an error if the user tries to set for another user" do
        sign_in(user1)
        topic.update(user_id: another_user.id)
        put "/u/#{another_user.username}/feature-topic.json", params: { topic_id: topic.id }
        expect(response.status).to eq(403)
      end

      it "returns an error if the topic is a PM" do
        sign_in(another_user)
        put "/u/#{another_user.username}/feature-topic.json",
            params: {
              topic_id: private_message.id,
            }
        expect(response.status).to eq(403)
      end

      it "returns an error if the topic is not visible" do
        sign_in(user1)
        topic.update_status("visible", false, user1)
        put "/u/#{user1.username}/feature-topic.json", params: { topic_id: topic.id }
        expect(response.status).to eq(403)
      end

      it "returns an error if the topic's category is read_restricted" do
        sign_in(user1)
        category.set_permissions({})
        topic.update(category_id: category.id)
        put "/u/#{another_user.username}/feature-topic.json", params: { topic_id: topic.id }
        expect(response.status).to eq(403)
      end

      it "sets featured_topic correctly for user created topic" do
        sign_in(user1)
        topic.update(user_id: user1.id)
        put "/u/#{user1.username}/feature-topic.json", params: { topic_id: topic.id }
        expect(response.status).to eq(200)
        expect(user1.user_profile.featured_topic).to eq topic
      end

      it "sets featured_topic correctly for non-user-created topic" do
        sign_in(user1)
        put "/u/#{user1.username}/feature-topic.json", params: { topic_id: other_topic.id }
        expect(response.status).to eq(200)
        expect(user1.user_profile.featured_topic).to eq other_topic
      end

      describe "site setting disabled" do
        before { SiteSetting.allow_featured_topic_on_user_profiles = false }

        it "does not allow setting featured_topic for user_profiles" do
          sign_in(user1)
          topic.update(user_id: user1.id)
          put "/u/#{user1.username}/feature-topic.json", params: { topic_id: topic.id }
          expect(response.status).to eq(403)
        end
      end
    end
  end

  describe "#clear_featured_topic" do
    fab!(:topic)

    it "requires the user to be logged in" do
      put "/u/#{user1.username}/clear-featured-topic.json"
      expect(response.status).to eq(403)
    end

    it "returns an error if the current user does not have access" do
      sign_in(user1)
      topic.update(user_id: another_user.id)
      put "/u/#{another_user.username}/clear-featured-topic.json"
      expect(response.status).to eq(403)
    end

    it "clears the user_profiles featured_topic correctly" do
      sign_in(user1)
      topic.update(user: user1)
      put "/u/#{user1.username}/clear-featured-topic.json"
      expect(response.status).to eq(200)
      expect(user1.user_profile.featured_topic).to eq nil
    end
  end

  describe "#bookmarks" do
    before do
      register_test_bookmarkable
      TopicUser.change(user1.id, bookmark1.bookmarkable.topic_id, total_msecs_viewed: 1)
      TopicUser.change(user1.id, bookmark2.bookmarkable_id, total_msecs_viewed: 1)
      Fabricate(:post, topic: bookmark2.bookmarkable)
      bookmark3 && bookmark4
    end

    after { DiscoursePluginRegistry.reset! }

    let(:bookmark1) { Fabricate(:bookmark, user: user1, bookmarkable: Fabricate(:post)) }
    let(:bookmark2) { Fabricate(:bookmark, user: user1, bookmarkable: Fabricate(:topic)) }
    let(:bookmark3) { Fabricate(:bookmark, user: user1, bookmarkable: Fabricate(:user)) }
    let(:bookmark4) { Fabricate(:bookmark) }

    it "returns a list of serialized bookmarks for the user" do
      sign_in(user1)
      get "/u/#{user1.username}/bookmarks.json"
      expect(response.status).to eq(200)
      expect(
        response.parsed_body["user_bookmark_list"]["bookmarks"].map { |b| b["id"] },
      ).to match_array([bookmark1.id, bookmark2.id, bookmark3.id])
    end

    it "returns a list of serialized bookmarks for the user including custom registered bookmarkables" do
      sign_in(user1)
      bookmark3.bookmarkable.user_profile.update!(bio_raw: "<p>Something cooked</p>")
      bookmark3.bookmarkable.user_profile.rebake!
      get "/u/#{user1.username}/bookmarks.json"
      expect(response.status).to eq(200)
      response_bookmarks = response.parsed_body["user_bookmark_list"]["bookmarks"]
      expect(response_bookmarks.map { |b| b["id"] }).to match_array(
        [bookmark1.id, bookmark2.id, bookmark3.id],
      )
      expect(response_bookmarks.find { |b| b["id"] == bookmark3.id }["excerpt"]).to eq(
        "Something cooked",
      )
    end

    it "returns an .ics file of bookmark reminders for the user in date order" do
      bookmark1.update!(name: nil, reminder_at: 1.day.from_now)
      bookmark2.update!(name: "Some bookmark note", reminder_at: 1.week.from_now)
      bookmark3.update!(name: nil, reminder_at: 2.weeks.from_now)

      sign_in(user1)
      get "/u/#{user1.username}/bookmarks.ics"
      expect(response.status).to eq(200)
      expect(response.body).to eq(<<~ICS)
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//Discourse//#{Discourse.current_hostname}//#{Discourse.full_version}//EN
        BEGIN:VEVENT
        UID:bookmark_reminder_##{bookmark1.id}@#{Discourse.current_hostname}
        DTSTAMP:#{bookmark1.updated_at.strftime(I18n.t("datetime_formats.formats.calendar_ics"))}
        DTSTART:#{bookmark1.reminder_at_ics}
        DTEND:#{bookmark1.reminder_at_ics(offset: 1.hour)}
        SUMMARY:#{bookmark1.bookmarkable.topic.title}
        DESCRIPTION:#{bookmark1.bookmarkable.full_url}
        URL:#{bookmark1.bookmarkable.full_url}
        END:VEVENT
        BEGIN:VEVENT
        UID:bookmark_reminder_##{bookmark2.id}@#{Discourse.current_hostname}
        DTSTAMP:#{bookmark2.updated_at.strftime(I18n.t("datetime_formats.formats.calendar_ics"))}
        DTSTART:#{bookmark2.reminder_at_ics}
        DTEND:#{bookmark2.reminder_at_ics(offset: 1.hour)}
        SUMMARY:Some bookmark note
        DESCRIPTION:#{bookmark2.bookmarkable.url}
        URL:#{bookmark2.bookmarkable.url}
        END:VEVENT
        BEGIN:VEVENT
        UID:bookmark_reminder_##{bookmark3.id}@#{Discourse.current_hostname}
        DTSTAMP:#{bookmark3.updated_at.strftime(I18n.t("datetime_formats.formats.calendar_ics"))}
        DTSTART:#{bookmark3.reminder_at_ics}
        DTEND:#{bookmark3.reminder_at_ics(offset: 1.hour)}
        SUMMARY:#{bookmark3.bookmarkable.username}
        DESCRIPTION:#{Discourse.base_url}/u/#{bookmark3.bookmarkable.username}
        URL:#{Discourse.base_url}/u/#{bookmark3.bookmarkable.username}
        END:VEVENT
        END:VCALENDAR
      ICS
    end

    it "does not show another user's bookmarks" do
      sign_in(Fabricate(:user))
      get "/u/#{bookmark3.user.username}/bookmarks.json"
      expect(response.status).to eq(403)
    end

    it "shows a helpful message if no bookmarks are found" do
      bookmark1.destroy
      bookmark2.destroy
      bookmark3.destroy
      sign_in(user1)
      get "/u/#{user1.username}/bookmarks.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["bookmarks"]).to eq([])
    end

    it "shows a helpful message if no bookmarks are found for the search" do
      sign_in(user1)
      get "/u/#{user1.username}/bookmarks.json", params: { q: "badsearch" }
      expect(response.status).to eq(200)
      expect(response.parsed_body["bookmarks"]).to eq([])
    end

    describe "when limit params is invalid" do
      before { sign_in(user1) }

      include_examples "invalid limit params",
                       "/u/someusername/bookmarks.json",
                       described_class::BOOKMARKS_LIMIT
    end
  end

  describe "#bookmarks excerpts" do
    fab!(:user)
    let!(:topic) { Fabricate(:topic, user: user) }
    let!(:post) { Fabricate(:post, topic: topic) }
    let!(:bookmark) { Fabricate(:bookmark, name: "Test", user: user, bookmarkable: topic) }

    it "uses the first post of the topic for the bookmarks excerpt" do
      TopicUser.change(
        user.id,
        bookmark.bookmarkable.id,
        { last_read_post_number: post.post_number },
      )

      sign_in(user)

      get "/u/#{user.username}/bookmarks.json"
      expect(response.status).to eq(200)
      bookmark_list = response.parsed_body["user_bookmark_list"]["bookmarks"]
      expected_excerpt = PrettyText.excerpt(topic.first_post.cooked, 300, keep_emoji_images: true)
      expect(bookmark_list.first["excerpt"]).to eq(expected_excerpt)
    end

    describe "bookmarkable_url" do
      context "with the link_to_first_unread_post option" do
        it "is a full topic URL to the first unread post in the topic when the option is set" do
          TopicUser.change(
            user.id,
            bookmark.bookmarkable.id,
            { last_read_post_number: post.post_number },
          )

          sign_in(user)

          get "/u/#{user.username}/user-menu-bookmarks.json"
          expect(response.status).to eq(200)
          bookmark_list = response.parsed_body["bookmarks"]

          expect(bookmark_list.first["bookmarkable_url"]).to end_with(
            "/t/#{topic.slug}/#{topic.id}/#{post.post_number + 1}",
          )
        end

        it "is a full topic URL to the first post in the topic when the option isn't set" do
          TopicUser.change(
            user.id,
            bookmark.bookmarkable.id,
            { last_read_post_number: post.post_number },
          )

          sign_in(user)

          get "/u/#{user.username}/bookmarks.json"
          expect(response.status).to eq(200)
          bookmark_list = response.parsed_body["user_bookmark_list"]["bookmarks"]

          expect(bookmark_list.first["bookmarkable_url"]).to end_with(
            "/t/#{topic.slug}/#{topic.id}",
          )
        end
      end
    end
  end

  describe "#private_message_topic_tracking_state" do
    fab!(:user_2) { Fabricate(:user, refresh_auto_groups: true) }

    fab!(:private_message) do
      create_post(
        user: user1,
        target_usernames: [user_2.username],
        archetype: Archetype.private_message,
      ).topic
    end

    before { sign_in(user_2) }

    it "does not allow an unauthorized user to access the state of another user" do
      get "/u/#{user1.username}/private-message-topic-tracking-state.json"

      expect(response.status).to eq(403)
    end

    it "returns the right response" do
      get "/u/#{user_2.username}/private-message-topic-tracking-state.json"

      expect(response.status).to eq(200)

      topic_state = response.parsed_body.first

      expect(topic_state["topic_id"]).to eq(private_message.id)
      expect(topic_state["highest_post_number"]).to eq(1)
      expect(topic_state["last_read_post_number"]).to eq(nil)
      expect(topic_state["notification_level"]).to eq(NotificationLevels.all[:watching])
      expect(topic_state["group_ids"]).to eq([])
    end
  end

  describe "#reset_recent_searches" do
    it "does nothing for anon" do
      delete "/u/recent-searches.json"
      expect(response.status).to eq(403)
    end

    it "works for logged in user" do
      freeze_time
      sign_in(user1)
      delete "/u/recent-searches.json"

      expect(response.status).to eq(200)
      user1.reload
      expect(user1.user_option.oldest_search_log_date).to be_within(5.seconds).of(1.second.ago)
    end
  end

  describe "#recent_searches" do
    it "does nothing for anon" do
      get "/u/recent-searches.json"
      expect(response.status).to eq(403)
    end

    it "works for logged in user" do
      freeze_time
      sign_in(user1)
      SiteSetting.log_search_queries = true
      user1.user_option.update!(oldest_search_log_date: nil)

      get "/u/recent-searches.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["recent_searches"]).to eq([])

      SearchLog.create!(
        term: "old one",
        user_id: user1.id,
        search_type: 1,
        ip_address: "192.168.0.1",
        created_at: 5.minutes.ago,
      )
      SearchLog.create!(
        term: "also old",
        user_id: user1.id,
        search_type: 1,
        ip_address: "192.168.0.1",
        created_at: 15.minutes.ago,
      )

      get "/u/recent-searches.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["recent_searches"]).to eq(["old one", "also old"])

      user1.user_option.update!(oldest_search_log_date: 20.minutes.ago)

      get "/u/recent-searches.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["recent_searches"]).to eq(["old one", "also old"])

      user1.user_option.update!(oldest_search_log_date: 10.seconds.ago)

      get "/u/recent-searches.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["recent_searches"]).to eq([])

      SearchLog.create!(
        term: "new search",
        user_id: user1.id,
        search_type: 1,
        ip_address: "192.168.0.1",
        created_at: 2.seconds.ago,
      )

      get "/u/recent-searches.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["recent_searches"]).to eq(["new search"])
    end

    it "shows an error message when log_search_queries are off" do
      sign_in(user1)
      SiteSetting.log_search_queries = false

      get "/u/recent-searches.json"

      expect(response.status).to eq(403)
      expect(response.parsed_body["error"]).to eq(I18n.t("user_activity.no_log_search_queries"))
    end
  end

  describe "#user_menu_bookmarks" do
    fab!(:post)
    fab!(:topic) { Fabricate(:post).topic }
    fab!(:bookmark_with_reminder) { Fabricate(:bookmark, user: user, bookmarkable: post) }
    fab!(:bookmark_without_reminder) { Fabricate(:bookmark, user: user, bookmarkable: topic) }

    before do
      TopicUser.change(user.id, post.topic.id, total_msecs_viewed: 1)
      TopicUser.change(user.id, topic.id, total_msecs_viewed: 1)
      BookmarkReminderNotificationHandler.new(bookmark_with_reminder).send_notification
    end

    context "when logged out" do
      it "responds with 404" do
        get "/u/#{user.username}/user-menu-bookmarks"
        expect(response.status).to eq(404)
      end
    end

    context "when logged in" do
      before { sign_in(user) }

      it "responds with 403 when requesting bookmarks list of another user" do
        get "/u/#{user1.username}/user-menu-bookmarks"
        expect(response.status).to eq(403)
      end

      it "sends an array of unread bookmark_reminder notifications" do
        bookmark_with_reminder2 = Fabricate(:bookmark, user: user, bookmarkable: Fabricate(:post))
        TopicUser.change(user.id, bookmark_with_reminder2.bookmarkable.topic, total_msecs_viewed: 1)
        BookmarkReminderNotificationHandler.new(bookmark_with_reminder2).send_notification

        user
          .notifications
          .where(notification_type: Notification.types[:bookmark_reminder])
          .where("data::json ->> 'bookmark_id' = ?", bookmark_with_reminder2.id.to_s)
          .first
          .update!(read: true)

        get "/u/#{user.username}/user-menu-bookmarks"
        expect(response.status).to eq(200)

        notifications = response.parsed_body["notifications"]
        expect(notifications.size).to eq(1)
        expect(notifications.first["data"]["bookmark_id"]).to eq(bookmark_with_reminder.id)
      end

      it "responds with an array of bookmarks that are not associated with any of the unread bookmark_reminder notifications" do
        get "/u/#{user.username}/user-menu-bookmarks"
        expect(response.status).to eq(200)

        bookmarks = response.parsed_body["bookmarks"]
        expect(bookmarks.size).to eq(1)
        expect(bookmarks.first["id"]).to eq(bookmark_without_reminder.id)

        bookmark_reminder =
          user
            .notifications
            .where(notification_type: Notification.types[:bookmark_reminder])
            .where("data::json ->> 'bookmark_id' = ?", bookmark_with_reminder.id.to_s)
            .first

        bookmark_reminder.update!(read: true)
        get "/u/#{user.username}/user-menu-bookmarks"
        expect(response.status).to eq(200)

        bookmarks = response.parsed_body["bookmarks"]
        expect(bookmarks.map { |bookmark| bookmark["id"] }).to contain_exactly(
          bookmark_with_reminder.id,
          bookmark_without_reminder.id,
        )

        data = bookmark_reminder.data_hash
        data.delete(:bookmark_id)
        bookmark_reminder.update!(data: data.to_json, read: false)

        get "/u/#{user.username}/user-menu-bookmarks"
        expect(response.status).to eq(200)

        notifications = response.parsed_body["notifications"]
        expect(notifications.size).to eq(0)

        bookmarks = response.parsed_body["bookmarks"]
        expect(bookmarks.map { |bookmark| bookmark["id"] }).to contain_exactly(
          bookmark_with_reminder.id,
          bookmark_without_reminder.id,
        )
      end

      it "fills up the remaining of the USER_MENU_LIST_LIMIT limit with bookmarks" do
        bookmark2 = Fabricate(:bookmark, user: user, bookmarkable: Fabricate(:post, topic: topic))

        stub_const(UsersController, "USER_MENU_LIST_LIMIT", 2) do
          get "/u/#{user.username}/user-menu-bookmarks"
        end
        expect(response.status).to eq(200)

        notifications = response.parsed_body["notifications"]
        expect(notifications.size).to eq(1)

        bookmarks = response.parsed_body["bookmarks"]
        expect(bookmarks.size).to eq(1)

        stub_const(UsersController, "USER_MENU_LIST_LIMIT", 3) do
          get "/u/#{user.username}/user-menu-bookmarks"
        end
        expect(response.status).to eq(200)

        notifications = response.parsed_body["notifications"]
        expect(notifications.size).to eq(1)

        bookmarks = response.parsed_body["bookmarks"]
        expect(bookmarks.size).to eq(2)

        BookmarkReminderNotificationHandler.new(bookmark2).send_notification

        stub_const(UsersController, "USER_MENU_LIST_LIMIT", 3) do
          get "/u/#{user.username}/user-menu-bookmarks"
        end
        expect(response.status).to eq(200)

        notifications = response.parsed_body["notifications"]
        expect(notifications.size).to eq(2)

        bookmarks = response.parsed_body["bookmarks"]
        expect(bookmarks.size).to eq(1)
      end

      it "does not return any unread notifications for bookmarks that the user no longer has access to" do
        bookmark_with_reminder2 = Fabricate(:bookmark, user: user, bookmarkable: Fabricate(:post))
        TopicUser.change(user.id, bookmark_with_reminder2.bookmarkable.topic, total_msecs_viewed: 1)
        BookmarkReminderNotificationHandler.new(bookmark_with_reminder2).send_notification

        bookmark_with_reminder2.bookmarkable.topic.update!(
          archetype: Archetype.private_message,
          category: nil,
        )

        get "/u/#{user.username}/user-menu-bookmarks"
        expect(response.status).to eq(200)

        notifications = response.parsed_body["notifications"]
        expect(notifications.size).to eq(1)
        expect(notifications.first["data"]["bookmark_id"]).to eq(bookmark_with_reminder.id)
      end

      it "shows unread notifications even if the bookmark has been deleted if they have bookmarkable data" do
        bookmark_with_reminder.destroy!

        get "/u/#{user.username}/user-menu-bookmarks"
        expect(response.status).to eq(200)

        notifications = response.parsed_body["notifications"]
        expect(notifications.size).to eq(1)
        expect(notifications.first["data"]["bookmark_id"]).to eq(bookmark_with_reminder.id)
      end

      it "does not show unread notifications if the bookmark has been deleted if they only have the bookmark_id data" do
        notif =
          Notification.find_by(
            topic: bookmark_with_reminder.bookmarkable.topic,
            post_number: bookmark_with_reminder.bookmarkable.post_number,
          )
        new_data = notif.data_hash
        new_data.delete(:bookmarkable_type)
        new_data.delete(:bookmarkable_id)
        notif.update!(data: JSON.dump(new_data))

        bookmark_with_reminder.destroy!

        get "/u/#{user.username}/user-menu-bookmarks"
        expect(response.status).to eq(200)

        notifications = response.parsed_body["notifications"]
        expect(notifications.size).to eq(0)
      end

      context "with `show_user_menu_avatars` setting enabled" do
        before { SiteSetting.show_user_menu_avatars = true }

        it "serializes acting_user_avatar into notifications" do
          get "/u/#{user.username}/user-menu-bookmarks"
          expect(response.status).to eq(200)

          first_notification = response.parsed_body["notifications"].first
          expect(first_notification["acting_user_avatar_template"]).to be_present
        end
      end
    end
  end

  describe "#user_menu_messages" do
    fab!(:group1) { Fabricate(:group, has_messages: true, users: [user]) }
    fab!(:group2) { Fabricate(:group, has_messages: true, users: [user, user1]) }
    fab!(:group3) { Fabricate(:group, has_messages: true, users: [user1]) }

    fab!(:message_without_notification) { Fabricate(:private_message_post, recipient: user).topic }
    fab!(:message_with_read_notification) do
      Fabricate(:private_message_post, recipient: user).topic
    end
    fab!(:message_with_unread_notification) do
      Fabricate(:private_message_post, recipient: user).topic
    end
    fab!(:archived_message) { Fabricate(:private_message_post, recipient: user).topic }

    fab!(:group_message1) { Fabricate(:group_private_message_post, recipients: group1).topic }
    fab!(:group_message2) { Fabricate(:group_private_message_post, recipients: group2).topic }
    fab!(:group_message3) { Fabricate(:group_private_message_post, recipients: group3).topic }

    fab!(:archived_group_message1) do
      Fabricate(:group_private_message_post, recipients: group1).topic
    end
    fab!(:archived_group_message2) do
      Fabricate(:group_private_message_post, recipients: group2).topic
    end

    fab!(:user1_message_without_notification) do
      Fabricate(:private_message_post, recipient: user1).topic
    end
    fab!(:user1_message_with_read_notification) do
      Fabricate(:private_message_post, recipient: user1).topic
    end
    fab!(:user1_message_with_unread_notification) do
      Fabricate(:private_message_post, recipient: user1).topic
    end
    fab!(:user1_archived_message) { Fabricate(:private_message_post, recipient: user1).topic }

    fab!(:unread_pm_notification) do
      Fabricate(
        :private_message_notification,
        read: false,
        user: user,
        topic: message_with_unread_notification,
        created_at: 4.minutes.ago,
      )
    end
    fab!(:read_pm_notification) do
      Fabricate(
        :private_message_notification,
        read: true,
        user: user,
        topic: message_with_read_notification,
      )
    end

    fab!(:unread_group_message_summary_notification) do
      Fabricate(
        :notification,
        read: false,
        user: user,
        notification_type: Notification.types[:group_message_summary],
        created_at: 2.minutes.ago,
      )
    end

    fab!(:read_group_message_summary_notification) do
      Fabricate(
        :notification,
        read: true,
        user: user,
        notification_type: Notification.types[:group_message_summary],
        created_at: 1.minutes.ago,
      )
    end

    fab!(:user1_unread_pm_notification) do
      Fabricate(
        :private_message_notification,
        read: false,
        user: user1,
        topic: user1_message_with_unread_notification,
      )
    end
    fab!(:user1_read_pm_notification) do
      Fabricate(
        :private_message_notification,
        read: true,
        user: user1,
        topic: user1_message_with_read_notification,
      )
    end

    fab!(:user1_unread_group_message_summary_notification) do
      Fabricate(
        :notification,
        read: false,
        user: user1,
        notification_type: Notification.types[:group_message_summary],
      )
    end
    fab!(:user1_read_group_message_summary_notification) do
      Fabricate(
        :notification,
        read: true,
        user: user1,
        notification_type: Notification.types[:group_message_summary],
      )
    end

    before do
      UserArchivedMessage.archive!(user.id, archived_message)
      UserArchivedMessage.archive!(user1.id, user1_archived_message)
      GroupArchivedMessage.archive!(group1.id, archived_group_message1)
      GroupArchivedMessage.archive!(group2.id, archived_group_message2)
    end

    context "when logged out" do
      it "responds with 404" do
        get "/u/#{user.username}/user-menu-private-messages"
        expect(response.status).to eq(404)
      end
    end

    context "when logged in" do
      before { sign_in(user) }

      it "responds with 403 when requesting messages list of another user" do
        get "/u/#{user1.username}/user-menu-private-messages"
        expect(response.status).to eq(403)
      end

      it "responds with 403 if personal_message_enabled_groups does not include the user and the user isn't staff" do
        SiteSetting.personal_message_enabled_groups = Group::AUTO_GROUPS[:trust_level_4]
        user.update(trust_level: 1)
        get "/u/#{user.username}/user-menu-private-messages"
        expect(response.status).to eq(403)
      end

      it "sends an array of unread private_message notifications" do
        get "/u/#{user.username}/user-menu-private-messages"
        expect(response.status).to eq(200)

        unread_notifications = response.parsed_body["unread_notifications"]
        expect(unread_notifications.map { |notification| notification["id"] }).to eq(
          [unread_pm_notification.id, unread_group_message_summary_notification.id],
        )
      end

      it "sends an array of read group_message_summary notifications" do
        read_group_message_summary_notification2 =
          Fabricate(
            :notification,
            read: true,
            user: user,
            notification_type: Notification.types[:group_message_summary],
            created_at: 5.minutes.ago,
          )
        get "/u/#{user.username}/user-menu-private-messages"
        expect(response.status).to eq(200)

        read_notifications = response.parsed_body["read_notifications"]
        expect(read_notifications.map { |notification| notification["id"] }).to eq(
          [read_group_message_summary_notification.id, read_group_message_summary_notification2.id],
        )
      end

      it "responds with an array of personal messages and user watching group messages that are not associated with any of the unread private_message notifications" do
        group_message1.update!(bumped_at: 1.minutes.ago)
        message_without_notification.update!(bumped_at: 3.minutes.ago)
        group_message2.update!(bumped_at: 6.minutes.ago)
        message_with_read_notification.update!(bumped_at: 10.minutes.ago)
        read_group_message_summary_notification.destroy!

        TopicUser.create!(
          user: user,
          topic: group_message1,
          notification_level: TopicUser.notification_levels[:watching],
        )
        TopicUser.create!(
          user: user,
          topic: group_message2,
          notification_level: TopicUser.notification_levels[:regular],
        )

        get "/u/#{user.username}/user-menu-private-messages"
        expect(response.status).to eq(200)

        topics = response.parsed_body["topics"]

        expect(topics.map { |topic| topic["id"] }).to eq(
          [group_message1.id, message_without_notification.id, message_with_read_notification.id],
        )
      end

      it "fills up the remaining of the USER_MENU_LIST_LIMIT limit with PM topics" do
        stub_const(UsersController, "USER_MENU_LIST_LIMIT", 3) do
          get "/u/#{user.username}/user-menu-private-messages"
        end
        expect(response.status).to eq(200)
        unread_notifications = response.parsed_body["unread_notifications"]
        expect(unread_notifications.size).to eq(2)

        topics = response.parsed_body["topics"]
        read_notifications = response.parsed_body["read_notifications"]
        expect(topics.size).to eq(1)
        expect(read_notifications.size).to eq(1)

        message2 = Fabricate(:private_message_post, recipient: user).topic
        Fabricate(:private_message_notification, read: false, user: user, topic: message2)

        stub_const(UsersController, "USER_MENU_LIST_LIMIT", 2) do
          get "/u/#{user.username}/user-menu-private-messages"
        end
        expect(response.status).to eq(200)
        unread_notifications = response.parsed_body["unread_notifications"]
        expect(unread_notifications.size).to eq(2)

        topics = response.parsed_body["topics"]
        read_notifications = response.parsed_body["read_notifications"]
        expect(topics.size).to eq(0)
        expect(read_notifications.size).to eq(0)
      end
    end
  end

  def create_second_factor_security_key
    sign_in(user1)
    stub_secure_session_confirmed
    post "/u/create_second_factor_security_key.json"
  end

  def stub_secure_session_confirmed
    UsersController.any_instance.stubs(:secure_session_confirmed?).returns(true)
  end
end
