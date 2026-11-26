# frozen_string_literal: true

require "discourse_connect_base"
require "oauth"
require "omniauth-google-oauth2"

RSpec.describe Users::OmniauthCallbacksController do
  fab!(:user)

  before { OmniAuth.config.test_mode = true }

  after do
    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2] = nil
    Rails.application.env_config["omniauth.origin"] = nil
    OmniAuth.config.test_mode = false
  end

  describe ".find_authenticator" do
    it "fails if a provider is disabled" do
      SiteSetting.enable_twitter_logins = false

      expect do Users::OmniauthCallbacksController.find_authenticator("twitter") end.to raise_error(
        Discourse::InvalidAccess,
      )
    end

    it "fails for unknown" do
      expect do
        Users::OmniauthCallbacksController.find_authenticator("twitter1")
      end.to raise_error(Discourse::InvalidAccess)
    end

    it "finds an authenticator when enabled" do
      enable_auth_provider(:twitter)

      expect(Users::OmniauthCallbacksController.find_authenticator("twitter")).not_to eq(nil)
    end

    context "with a plugin-contributed auth provider" do
      let :provider do
        provider = Auth::AuthProvider.new
        provider.authenticator =
          Class
            .new(Auth::Authenticator) do
              def name
                "ubuntu"
              end

              def enabled?
                SiteSetting.ubuntu_login_enabled
              end
            end
            .new

        provider
      end

      before { DiscoursePluginRegistry.register_auth_provider(provider) }

      after { DiscoursePluginRegistry.reset! }

      it "finds an authenticator when enabled" do
        SiteSetting.stubs(:ubuntu_login_enabled).returns(true)

        expect(Users::OmniauthCallbacksController.find_authenticator("ubuntu")).to be(
          provider.authenticator,
        )
      end

      it "fails if an authenticator is disabled" do
        SiteSetting.stubs(:ubuntu_login_enabled).returns(false)

        expect { Users::OmniauthCallbacksController.find_authenticator("ubuntu") }.to raise_error(
          Discourse::InvalidAccess,
        )
      end
    end
  end

  describe "Google Oauth2" do
    before { enable_auth_provider(:google_oauth2) }

    describe "#failure" do
      it "defaults to the provider when only one is enabled" do
        get "/auth/failure"
        expect(response.status).to eq(200)
        expect(response.body).to include(
          I18n.t("login.omniauth_error.generic_with_provider", provider: "Google"),
        )

        get "/auth/failure", params: { provider: "facebook" }
        expect(response.status).to eq(200)
        expect(response.body).to include(
          I18n.t("login.omniauth_error.generic_with_provider", provider: "Google"),
        )
      end

      it "uses the provider parameter when matching an enabled authenticator" do
        enable_auth_provider(:facebook)

        get "/auth/failure", params: { provider: "facebook" }
        expect(response.status).to eq(200)
        expect(response.body).to include(
          I18n.t("login.omniauth_error.generic_with_provider", provider: "Facebook"),
        )
      end

      it "uses the strategy parameter when matching an enabled authenticator" do
        enable_auth_provider(:facebook)

        get "/auth/failure", params: { strategy: "facebook" }
        expect(response.status).to eq(200)
        expect(response.body).to include(
          I18n.t("login.omniauth_error.generic_with_provider", provider: "Facebook"),
        )
      end

      it "shows a generic error message when there are more than one enabled providers" do
        enable_auth_provider(:facebook)

        get "/auth/failure"
        expect(response.status).to eq(200)
        expect(response.body).to include(I18n.t("login.omniauth_error.generic_without_provider"))
      end

      # rubocop:disable Discourse/NoIterationOverRSpecDefinitions
      Users::OmniauthCallbacksController::ALLOWED_FAILURE_ERRORS.each_key do |error|
        it "supports specific '#{error}' messages" do
          get "/auth/failure", params: { message: error }
          expect(response.status).to eq(200)
          expect(flash[:error]).to include(I18n.t("login.omniauth_error.#{error}"))
        end
      end
      # rubocop:enable Discourse/NoIterationOverRSpecDefinitions

      it "falls back to generic error when the specific error doesn't exist" do
        get "/auth/failure", params: { message: "foo_bar" }
        expect(response.status).to eq(200)
        expect(response.body).to include(
          I18n.t("login.omniauth_error.generic_with_provider", provider: "Google"),
        )
      end

      it "HTML-escapes the provider display name in the error message" do
        display_name = "<Custom & Provider>"
        authenticator = Auth::GoogleOAuth2Authenticator.new
        authenticator.stubs(:display_name).returns(display_name)
        Discourse.stubs(:enabled_authenticators).returns([authenticator])

        get "/auth/failure", params: { provider: "google_oauth2" }

        expect(response.status).to eq(200)
        expect(response.body).not_to include(display_name)
        expect(response.body).to include(CGI.escapeHTML(display_name))
      end
    end

    describe "request" do
      it "returns an error for nonexistent authenticators" do
        post "/auth/fake_auth"
        expect(response.status).to eq(404)
        get "/auth/fake_auth"
        expect(response.status).to eq(403)
      end

      it "returns an error for disabled authenticators" do
        SiteSetting.enable_google_oauth2_logins = false
        post "/auth/google_oauth2"
        expect(response.status).to eq(404)
        get "/auth/google_oauth2"
        expect(response.status).to eq(403)
      end

      it "handles common authentication errors" do
        OmniAuth::Strategies::GoogleOauth2
          .any_instance
          .stubs(:mock_request_call)
          .raises(
            OAuth::Unauthorized.new(
              mock().tap do |m|
                m.stubs(:code).returns(403)
                m.stubs(:message).returns("Message")
              end,
            ),
          )
        post "/auth/google_oauth2"
        expect(response.status).to eq(302)
        expect(response.location).to include("/auth/failure?message=unauthorized")

        OmniAuth::Strategies::GoogleOauth2
          .any_instance
          .stubs(:mock_request_call)
          .raises(JWT::InvalidIatError.new)
        post "/auth/google_oauth2"
        expect(response.status).to eq(302)
        expect(response.location).to include("/auth/failure?message=invalid_iat")
      end

      it "starts authentication only through a POST request" do
        post "/auth/google_oauth2"
        expect(response.status).to eq(302)
        get "/auth/google_oauth2"
        expect(response.status).to eq(200)
      end

      context "with CSRF protection enabled" do
        before { ActionController::Base.allow_forgery_protection = true }
        after { ActionController::Base.allow_forgery_protection = false }

        it "requires CSRF protection" do
          post "/auth/google_oauth2"
          expect(response.status).to eq(302)
          expect(response.location).to include("/auth/failure?message=csrf_detected")

          post "/auth/google_oauth2", params: { authenticity_token: "faketoken" }
          expect(response.status).to eq(302)
          expect(response.location).to include("/auth/failure?message=csrf_detected")

          get "/session/csrf.json"
          token = response.parsed_body["csrf"]

          post "/auth/google_oauth2", params: { authenticity_token: token }
          expect(response.status).to eq(302)
          expect(URI(response.location).path).to eq("/auth/google_oauth2/callback")
        end

        it "allows authentication without CSRF protection when it is the only method" do
          get "/auth/google_oauth2"
          expect(response.status).to eq(200)
          SiteSetting.enable_local_logins = false
          get "/auth/google_oauth2"
          expect(response.status).to eq(302)
        end

        it "allows authentication without CSRF protection when disabled in settings" do
          SiteSetting.auth_require_interaction = false
          SiteSetting.enable_local_logins = true
          get "/auth/google_oauth2"
          expect(response.status).to eq(302)
        end
      end
    end

    context "when in readonly mode" do
      before { Discourse.enable_readonly_mode }

      it "returns a 503 (GET)" do
        get "/auth/google_oauth2/callback"
        expect(response.status).to eq(503)
      end

      it "returns a 503 (POST)" do
        post "/auth/google_oauth2/callback"
        expect(response.status).to eq(503)
      end
    end

    context "when in staff writes only mode" do
      before { Discourse.enable_readonly_mode(Discourse::STAFF_WRITES_ONLY_MODE_KEY) }

      it "returns a 503 for non-staff (GET)" do
        mock_auth(user.email, user.username, user.name)
        get "/auth/google_oauth2/callback.json"
        expect(response.status).to eq(503)
        expect(Discourse.current_user_provider.new(request.env).current_user).to eq(nil)
      end

      it "returns a 503 for non-staff (POST)" do
        mock_auth(user.email, user.username, user.name)
        post "/auth/google_oauth2/callback.json"
        expect(response.status).to eq(503)
        expect(Discourse.current_user_provider.new(request.env).current_user).to eq(nil)
      end

      it "completes for admins (GET)" do
        user.update!(admin: true)
        mock_auth(user.email, user.username, user.name)
        get "/auth/google_oauth2/callback.json"
        expect(response.status).to eq(302)
        expect(Discourse.current_user_provider.new(request.env).current_user).to eq(user)
      end

      it "completes for moderators (POST)" do
        user.update!(moderator: true)
        mock_auth(user.email, user.username, user.name)
        post "/auth/google_oauth2/callback.json"
        expect(response.status).to eq(302)
        expect(Discourse.current_user_provider.new(request.env).current_user).to eq(user)
      end
    end

    context "without an `omniauth.auth` env" do
      it "returns 404" do
        get "/auth/eviltrout/callback"
        expect(response.code).to eq("404")
      end
    end

    describe "when user not found" do
      let(:email) { "somename@gmail.com" }
      let(:username) { "somename" }
      let(:name) { "Some Name" }

      before { mock_auth(email, username, name) }

      it "redirects with authentication details for the new user" do
        destination_url = "/somepath"
        Rails.application.env_config["omniauth.origin"] = destination_url

        events = DiscourseEvent.track_events { get "/auth/google_oauth2/callback.json" }
        expect(events.any? { |e| e[:event_name] == :before_auth }).to eq(true)
        expect(
          events.any? do |e|
            e[:event_name] === :after_auth && Auth::GoogleOAuth2Authenticator === e[:params][0] &&
              !e[:params][1].failed?
          end,
        ).to eq(true)

        expect(response.status).to eq(302)

        data = JSON.parse(cookies[:authentication_data])

        expect(data["email"]).to eq(email)
        expect(data["username"]).to eq(username)
        expect(data["name"]).to eq(name)
        expect(data["auth_provider"]).to eq("google_oauth2")
        expect(data["email_valid"]).to eq(true)
        expect(data["can_edit_username"]).to eq(true)
        expect(data["destination_url"]).to eq(destination_url)
      end

      it "redirects with authentication details for staged users" do
        Fabricate(:user, username: username, email: email, staged: true)

        destination_url = "/somepath"
        Rails.application.env_config["omniauth.origin"] = destination_url

        events = DiscourseEvent.track_events { get "/auth/google_oauth2/callback.json" }
        expect(events.any? { |e| e[:event_name] == :before_auth }).to eq(true)
        expect(
          events.any? do |e|
            e[:event_name] === :after_auth && Auth::GoogleOAuth2Authenticator === e[:params][0] &&
              !e[:params][1].failed?
          end,
        ).to eq(true)

        expect(response.status).to eq(302)

        data = JSON.parse(cookies[:authentication_data])

        expect(data["email"]).to eq(email)
        expect(data["username"]).to eq(username)
        expect(data["auth_provider"]).to eq("google_oauth2")
        expect(data["email_valid"]).to eq(true)
        expect(data["can_edit_username"]).to eq(true)
        expect(data["name"]).to eq("Some Name")
        expect(data["destination_url"]).to eq(destination_url)
      end

      it "includes the destination URL in the response" do
        destination_url = "/cookiepath"
        cookies[:destination_url] = destination_url

        get "/auth/google_oauth2/callback.json"

        data = JSON.parse(cookies[:authentication_data])
        expect(data["destination_url"]).to eq(destination_url)
      end

      it "returns an association URL when multiple login methods are enabled" do
        get "/auth/google_oauth2/callback.json"
        expect(response.status).to eq(302)

        data = JSON.parse(cookies[:authentication_data])
        expect(data["associate_url"]).to start_with("/associate/")

        SiteSetting.enable_local_logins = false
        get "/auth/google_oauth2/callback.json"
        data = JSON.parse(cookies[:authentication_data])
        expect(data["associate_url"]).to eq(nil)
      end

      it "does not use email for username suggestions if disabled in settings" do
        SiteSetting.use_email_for_username_and_name_suggestions = false
        username = ""
        name = ""
        email = "billmailbox@test.com"
        mock_auth(email, username, name)

        get "/auth/google_oauth2/callback.json"
        data = JSON.parse(cookies[:authentication_data])

        # leaves field blank for user to choose
        expect(data["username"]).to eq(nil)
      end

      it "uses email for username suggestions if enabled in settings" do
        SiteSetting.use_email_for_username_and_name_suggestions = true
        username = ""
        name = ""
        email = "billmailbox@test.com"
        mock_auth(email, username, name)

        get "/auth/google_oauth2/callback.json"
        data = JSON.parse(cookies[:authentication_data])

        expect(data["username"]).to eq("billmailbox")
      end

      it "stops using name for username suggestions if disabled in settings" do
        SiteSetting.use_name_for_username_suggestions = false
        username = ""
        name = "John Smith"
        email = "billmailbox@test.com"
        mock_auth(email, username, name)

        get "/auth/google_oauth2/callback.json"
        data = JSON.parse(cookies[:authentication_data])

        # leaves field blank for user to choose
        expect(data["username"]).to eq(nil)
      end

      describe "when site is invite_only" do
        before { SiteSetting.invite_only = true }

        it "requires an invitation when no origin is supplied" do
          get "/auth/google_oauth2/callback.json"

          expect(response.status).to eq(302)

          data = JSON.parse(response.cookies["authentication_data"])

          expect(data["requires_invite"]).to eq(true)
        end

        it "returns the right response for an invalid origin" do
          Rails.application.env_config["omniauth.origin"] = "/invitesinvites"

          get "/auth/google_oauth2/callback.json"

          expect(response.status).to eq(302)
        end

        it "redirects to the invitation page without requiring another invite" do
          origin =
            Rails.application.routes.url_helpers.invite_url(
              Fabricate(:invite).invite_key,
              host: Discourse.base_url,
            )

          Rails.application.env_config["omniauth.origin"] = origin

          get "/auth/google_oauth2/callback.json"

          expect(response.status).to eq(302)
          expect(response).to redirect_to(origin)

          data = JSON.parse(response.cookies["authentication_data"])

          expect(data["requires_invite"]).to eq(nil)
        end

        it "requires invite when origin is a non-invite route containing an invite key" do
          invite = Fabricate(:invite)
          Rails.application.env_config["omniauth.origin"] = "/t/#{invite.invite_key}"

          get "/auth/google_oauth2/callback.json"

          expect(response.status).to eq(302)
          data = JSON.parse(response.cookies["authentication_data"])
          expect(data["requires_invite"]).to eq(true)
        end

        it "requires invite when the invite is not redeemable" do
          invite = Fabricate(:invite, expires_at: 1.day.ago)
          origin =
            Rails.application.routes.url_helpers.invite_url(
              invite.invite_key,
              host: Discourse.base_url,
            )
          Rails.application.env_config["omniauth.origin"] = origin

          get "/auth/google_oauth2/callback.json"

          expect(response.status).to eq(302)
          data = JSON.parse(response.cookies["authentication_data"])
          expect(data["requires_invite"]).to eq(true)
        end
      end
    end

    describe "when user has been verified" do
      let(:uid) { 12_345 }

      before { mock_auth(user.email, "Somenickname", "Some name", uid) }

      it "authenticates the user and confirms their email" do
        expect(user.email_confirmed?).to eq(false)

        events = DiscourseEvent.track_events { get "/auth/google_oauth2/callback.json" }

        expect(events.map { |event| event[:event_name] }).to include(
          :user_logged_in,
          :user_first_logged_in,
        )

        expect(response.status).to eq(302)

        data = JSON.parse(cookies[:authentication_data])

        expect(data["authenticated"]).to eq(true)
        expect(data["awaiting_activation"]).to eq(false)
        expect(data["awaiting_approval"]).to eq(false)
        expect(data["not_allowed_from_ip_address"]).to eq(false)
        expect(data["admin_not_allowed_from_ip_address"]).to eq(false)

        user.reload
        expect(user.email_confirmed?).to eq(true)
        expect(user.user_auth_tokens.last.authenticated_with_oauth).to be true
      end

      it "includes the subfolder in the authenticated response path" do
        set_subfolder "/forum"
        events = DiscourseEvent.track_events { get "/auth/google_oauth2/callback.json" }

        expect(
          response.headers["Set-Cookie"].match(%r{^authentication_data=.*; path=/forum}),
        ).not_to eq(nil)

        expect(events.map { |event| event[:event_name] }).to include(
          :user_logged_in,
          :user_first_logged_in,
        )

        expect(response.status).to eq(302)

        data = JSON.parse(response.cookies["authentication_data"])

        expect(data["authenticated"]).to eq(true)
        expect(data["awaiting_activation"]).to eq(false)
        expect(data["awaiting_approval"]).to eq(false)
        expect(data["not_allowed_from_ip_address"]).to eq(false)
        expect(data["admin_not_allowed_from_ip_address"]).to eq(false)

        user.reload
        expect(user.email_confirmed?).to eq(true)
      end

      it "confirms email even when the tokens are expired" do
        user.email_tokens.update_all(confirmed: false, expired: true)

        user.reload
        expect(user.email_confirmed?).to eq(false)

        events = DiscourseEvent.track_events { get "/auth/google_oauth2/callback.json" }

        expect(events.map { |event| event[:event_name] }).to include(
          :user_logged_in,
          :user_first_logged_in,
        )

        expect(response.status).to eq(302)

        user.reload
        expect(user.email_confirmed?).to eq(true)
      end

      it "treats a staged user as an unregistered user" do
        user.update!(staged: true, registration_ip_address: nil)

        user.reload
        expect(user.staged).to eq(true)
        expect(user.registration_ip_address).to eq(nil)

        events = DiscourseEvent.track_events { get "/auth/google_oauth2/callback.json" }

        expect(events.map { |event| event[:event_name] }).to include(:before_auth, :after_auth)

        expect(response.status).to eq(302)

        data = JSON.parse(cookies[:authentication_data])
        expect(data["username"]).to eq("Somenickname")

        user.reload
        expect(user.staged).to eq(true)
        expect(user.registration_ip_address).to eq(nil)

        # Now register
        UsersController.any_instance.stubs(:honeypot_value).returns(nil)
        UsersController.any_instance.stubs(:challenge_value).returns(nil)
        post "/u.json",
             params: {
               name: "My new name",
               username: "mynewusername",
               email: user.email,
             }

        expect(response.status).to eq(200)

        user.reload
        expect(user.staged).to eq(false)
        expect(user.registration_ip_address).to be_present
        expect(user.name).to eq("My new name")
      end

      it "activates the user with a matching email" do
        user.update!(password: "securepassword", active: false, registration_ip_address: "1.1.1.1")

        user.reload
        expect(user.active).to eq(false)
        expect(user.confirm_password?("securepassword")).to eq(true)

        get "/auth/google_oauth2/callback.json"

        user.reload
        expect(user.active).to eq(true)

        # Delete the password, it may have been set by someone else
        expect(user.confirm_password?("securepassword")).to eq(false)
      end

      it "authenticates an invited user without email tokens" do
        # Confirming existing email_tokens has a side effect of redeeming invites.
        # Pretend we don't have any email_tokens
        user.email_tokens.destroy_all

        invite = Fabricate(:invite, invited_by: Fabricate(:admin))
        invite.update_column(:email, user.email) # (avoid validation)

        get "/auth/google_oauth2/callback.json"
        expect(response.status).to eq(302)

        expect(invite.reload.invalidated_at).not_to eq(nil)
      end

      it "updates name, username, and email when authentication overrides are enabled" do
        SiteSetting.email_editable = false
        SiteSetting.auth_overrides_email = true
        SiteSetting.auth_overrides_name = true
        SiteSetting.auth_overrides_username = true

        UserAssociatedAccount.create!(
          provider_name: "google_oauth2",
          user_id: user.id,
          provider_uid: uid,
        )

        old_email = user.email
        user.update!(name: "somename", username: "somusername", email: "email@example.com")

        get "/auth/google_oauth2/callback.json"
        expect(response.status).to eq(302)

        user.reload
        expect(user.email).to eq(old_email)
        expect(user.username).to eq("Somenickname")
        expect(user.name).to eq("Some name")
      end

      it "preserves usernames when several users log in with the same username" do
        SiteSetting.auth_overrides_username = true

        # if several users have username "bill" on the external site,
        # they will have usernames bill, bill1, bill2 etc in Discourse:
        Fabricate(:user, username: "bill")
        Fabricate(:user, username: "bill1")
        Fabricate(:user, username: "bill2")
        Fabricate(:user, username: "bill4")

        # the number should be preserved during subsequent logins
        # bill3 should remain bill3
        user.update!(username: "bill3")

        uid = "12345"
        UserAssociatedAccount.create!(
          provider_name: "google_oauth2",
          user_id: user.id,
          provider_uid: uid,
        )
        mock_auth(user.email, "bill", uid)

        get "/auth/google_oauth2/callback.json"

        user.reload
        expect(user.username).to eq("bill3")
      end

      it "does not update an unverified email" do
        SiteSetting.email_editable = false
        SiteSetting.auth_overrides_email = true

        OmniAuth.config.mock_auth[:google_oauth2][:extra][:raw_info][:email_verified] = false

        UserAssociatedAccount.create!(
          provider_name: "google_oauth2",
          user_id: user.id,
          provider_uid: "123545",
        )

        user.update!(email: "email@example.com")

        get "/auth/google_oauth2/callback.json"
        expect(response.status).to eq(302)

        user.reload
        expect(user.email).to eq("email@example.com")
      end

      it "shows error when auth_overrides_email causes a validation error" do
        SiteSetting.email_editable = false
        SiteSetting.auth_overrides_email = true

        UserAssociatedAccount.create!(
          provider_name: "google_oauth2",
          user_id: user.id,
          provider_uid: uid,
        )

        google_email = user.email
        user.update!(email: "anotheremail@example.com")
        Fabricate(:user, email: google_email) # Another user has the google account email

        get "/auth/google_oauth2/callback"
        expect(response.status).to eq(200)
        expect(response.body).to include(I18n.t("errors.messages.taken"))
        expect(session[:current_user_id]).to eq(nil)

        user.reload
        expect(user.email).to eq("anotheremail@example.com")
      end

      it "sanitizes custom failed auth result HTML" do
        link_html =
          '<a href="https://example.com/help" target="_blank" rel="noopener" onclick="alert(1)">Learn more</a>'
        failed_result = Auth::Result.new
        failed_result.failed = true
        failed_result.failed_reason = [
          "Partner accounts only.",
          link_html,
          "<script>alert(1)</script>",
        ].join("\n")

        Auth::GoogleOAuth2Authenticator
          .any_instance
          .stubs(:after_authenticate)
          .returns(failed_result)

        get "/auth/google_oauth2/callback"

        document = Nokogiri.HTML5(response.body)
        alert = document.at_css(".alert-error")
        link = alert.at_css("a")

        aggregate_failures do
          expect(response.status).to eq(200)
          expect(alert.text).to include("Partner accounts only.")
          expect(link["href"]).to eq("https://example.com/help")
          expect(link["target"]).to eq("_blank")
          expect(link["onclick"]).to be_nil
          expect(alert.to_html).not_to include("<script")
        end
      end

      context "when the user has TOTP enabled" do
        let!(:totp) { user.create_totp(enabled: true) }

        def start_omniauth_challenge(method: :get)
          public_send(method, "/auth/google_oauth2/callback")
          location = URI(response.location)
          expect(location.path).to eq("/session/2fa")
          Rack::Utils.parse_query(location.query).fetch("nonce")
        end

        def verify_totp(nonce, token: totp.totp_object.now)
          post "/session/2fa.json",
               params: {
                 nonce:,
                 second_factor_method: UserSecondFactor.methods[:totp],
                 second_factor_token: token,
               },
               xhr: true
        end

        it "signs in only after a native challenge and returns to the original destination" do
          SiteSetting.auth_overrides_name = true
          user.update!(active: false, name: "Original name")
          cookies[:destination_url] = "/t/123?source=login"

          nonce = nil
          expect { nonce = start_omniauth_challenge }.not_to change(UserAuthToken, :count)
          expect(cookies[:authentication_data]).to be_blank
          expect(user.reload).to have_attributes(active: false, name: "Original name")

          post "/auth/second-factor.json", params: { second_factor_nonce: nonce }, xhr: true
          expect(response.status).to eq(401)

          verify_totp(nonce, token: "invalid")
          expect(response.status).to eq(400)

          verify_totp(nonce)
          expect(response.status).to eq(200)
          callback = response.parsed_body
          expect(callback).to include(
            "callback_method" => "POST",
            "callback_path" => "/auth/second-factor",
          )
          expect(user.user_auth_tokens).to be_empty

          # There is no provider response to authenticate again during the continuation.
          Rails.application.env_config["omniauth.auth"] = nil
          post callback.fetch("callback_path"), params: { second_factor_nonce: nonce }, xhr: true
          expect(response.status).to eq(200)
          expect(response.parsed_body).to include(
            "redirect_url" => "/t/123?source=login",
            "reload" => true,
          )
          auth_data = JSON.parse(cookies[:authentication_data])
          expect(auth_data).to include("authenticated" => true)
          expect(auth_data).not_to have_key("associate_url")
          expect(cookies["_bypass_cache"]).to eq("true")
          expect(user.reload).to have_attributes(active: true, name: "Some name")
          expect(user.user_auth_tokens.sole.authenticated_with_oauth).to eq(true)
          get "/session/current.json"
          expect(response.parsed_body.dig("current_user", "id")).to eq(user.id)

          expect do
            post callback.fetch("callback_path"), params: { second_factor_nonce: nonce }, xhr: true
          end.not_to change(UserAuthToken, :count)
          expect(response.status).to eq(404)
        end

        it "binds a POST provider callback challenge to the browser session" do
          nonce = start_omniauth_challenge(method: :post)
          verify_totp(nonce)
          expect(response.status).to eq(200)

          another_browser = open_session
          another_browser.post "/auth/second-factor.json",
                               params: {
                                 second_factor_nonce: nonce,
                               },
                               xhr: true
          expect(another_browser.response.status).to eq(404)
          expect(user.user_auth_tokens).to be_empty
        end

        it "uses subfolder-aware challenge and continuation paths" do
          set_subfolder "/forum"

          get "/auth/google_oauth2/callback", env: { "SCRIPT_NAME" => "/forum" }
          location = URI(response.location)
          expect(location.path).to eq("/forum/session/2fa")
          nonce = Rack::Utils.parse_query(location.query).fetch("nonce")
          verify_totp(nonce)
          expect(response.parsed_body["callback_path"]).to eq("/forum/auth/second-factor")

          post "/auth/second-factor.json", params: { second_factor_nonce: nonce }, xhr: true
          expect(response.parsed_body["redirect_url"]).to eq("/forum")
        end

        it "requires CSRF protection on the continuation, not the provider callback" do
          ActionController::Base.allow_forgery_protection = true
          nonce = start_omniauth_challenge(method: :post)
          get "/session/csrf.json"
          csrf = response.parsed_body.fetch("csrf")
          post "/session/2fa.json",
               params: {
                 nonce:,
                 second_factor_method: UserSecondFactor.methods[:totp],
                 second_factor_token: totp.totp_object.now,
               },
               headers: {
                 "X-CSRF-Token" => csrf,
               },
               xhr: true
          expect(response.status).to eq(200)

          post "/auth/second-factor.json", params: { second_factor_nonce: nonce }, xhr: true
          expect(response.status).to eq(403)
          expect(user.user_auth_tokens).to be_empty

          get "/session/csrf.json"
          post "/auth/second-factor.json",
               params: {
                 second_factor_nonce: nonce,
               },
               headers: {
                 "X-CSRF-Token" => response.parsed_body.fetch("csrf"),
               },
               xhr: true
          expect(response.status).to eq(200)
        ensure
          ActionController::Base.allow_forgery_protection = false
        end

        it "rejects expired verified challenges" do
          nonce = start_omniauth_challenge
          verify_totp(nonce)
          expect(response.status).to eq(200)

          freeze_time 7.minutes.from_now
          post "/auth/second-factor.json", params: { second_factor_nonce: nonce }, xhr: true
          expect(response.status).to eq(401)
          expect(user.user_auth_tokens).to be_empty
        end

        it "rejects a verified challenge if the account is subsequently suspended" do
          nonce = start_omniauth_challenge
          verify_totp(nonce)
          expect(response.status).to eq(200)
          user.update!(suspended_till: 1.day.from_now)

          post "/auth/second-factor.json", params: { second_factor_nonce: nonce }, xhr: true
          expect(response.status).to eq(403)
          expect(user.user_auth_tokens).to be_empty
        end

        it "does not reactivate an account deactivated after the challenge started" do
          nonce = start_omniauth_challenge
          verify_totp(nonce)
          user.update!(active: false)

          post "/auth/second-factor.json", params: { second_factor_nonce: nonce }, xhr: true
          expect(response.status).to eq(403)
          expect(user.reload.active).to eq(false)
          expect(user.user_auth_tokens).to be_empty
        end

        it "rejects a challenge if its provider association is revoked" do
          nonce = start_omniauth_challenge
          verify_totp(nonce)
          UserAssociatedAccount.find_by!(provider_name: "google_oauth2", user:).destroy!

          post "/auth/second-factor.json", params: { second_factor_nonce: nonce }, xhr: true
          expect(response.status).to eq(403)
          expect(user.user_auth_tokens).to be_empty
        end

        it "does not apply stale provider attributes after the saved association changes" do
          nonce = start_omniauth_challenge
          verify_totp(nonce)
          freeze_time 1.second.from_now
          user.user_associated_accounts.sole.update!(info: { "name" => "Updated provider profile" })
          expect do
            post "/auth/second-factor.json", params: { second_factor_nonce: nonce }, xhr: true
          end.not_to change(UserAuthToken, :count)
          expect(response).to have_http_status(:forbidden)
        end

        it "rejects a challenge if the target account email changes" do
          nonce = start_omniauth_challenge
          verify_totp(nonce)
          user.update!(email: "changed@example.com")

          post "/auth/second-factor.json", params: { second_factor_nonce: nonce }, xhr: true
          expect(response.status).to eq(403)
          expect(user.user_auth_tokens).to be_empty
        end

        it "does not issue a new token for a signed-in target account before verification" do
          sign_in(user)
          token_count = user.user_auth_tokens.count
          nonce = start_omniauth_challenge
          expect(user.user_auth_tokens.count).to eq(token_count)
          verify_totp(nonce)

          post "/auth/second-factor.json", params: { second_factor_nonce: nonce }, xhr: true
          expect(response.status).to eq(200)
          expect(user.user_auth_tokens.where(authenticated_with_oauth: true).count).to eq(1)
        end

        it "cannot use an anonymous login challenge after another login signs in the same account" do
          nonce = start_omniauth_challenge
          verify_totp(nonce)
          sign_in(user)

          expect do
            post "/auth/second-factor.json", params: { second_factor_nonce: nonce }, xhr: true
          end.not_to change(UserAuthToken, :count)
          expect(response).to have_http_status(:not_found)
        end

        it "cannot finish a reauthentication challenge from a replaced session for the same user" do
          sign_in(user)
          nonce = start_omniauth_challenge
          verify_totp(nonce)
          sign_in(user)

          expect do
            post "/auth/second-factor.json", params: { second_factor_nonce: nonce }, xhr: true
          end.not_to change(UserAuthToken, :count)
          expect(response).to have_http_status(:not_found)
        end

        it "does not switch the signed-in account until verification" do
          sign_in(Fabricate(:user))
          nonce = start_omniauth_challenge
          expect(user.user_auth_tokens).to be_empty
          verify_totp(nonce)

          post "/auth/second-factor.json", params: { second_factor_nonce: nonce }, xhr: true
          expect(response.status).to eq(200)
          expect(user.user_auth_tokens.sole.authenticated_with_oauth).to eq(true)
        end

        it "preserves the awaiting-approval result without prompting for a factor" do
          SiteSetting.must_approve_users = true
          user.reload.update!(approved: false)
          user.email_tokens.update_all(confirmed: true)

          get "/auth/google_oauth2/callback"
          expect(response).to redirect_to("/")
          expect(JSON.parse(cookies[:authentication_data])).to include("awaiting_approval" => true)
          expect(user.user_auth_tokens).to be_empty
        end

        it "accepts a backup code instead of TOTP" do
          backup_code = user.generate_backup_codes.first
          nonce = start_omniauth_challenge
          post "/session/2fa.json",
               params: {
                 nonce:,
                 second_factor_method: UserSecondFactor.methods[:backup_codes],
                 second_factor_token: backup_code,
               },
               xhr: true
          expect(response.status).to eq(200)

          post response.parsed_body.fetch("callback_path"),
               params: {
                 second_factor_nonce: nonce,
               },
               xhr: true
          expect(response.status).to eq(200)
          expect(user.user_auth_tokens.sole.authenticated_with_oauth).to eq(true)
        end

        it "allows staff sign-in and blocks non-staff in staff-writes-only mode" do
          Discourse.enable_readonly_mode(Discourse::STAFF_WRITES_ONLY_MODE_KEY)

          get "/auth/google_oauth2/callback"
          expect(response.status).to eq(503)

          user.update!(admin: true)
          nonce = start_omniauth_challenge
          verify_totp(nonce)
          expect(response.status).to eq(200)

          post "/auth/second-factor.json", params: { second_factor_nonce: nonce }, xhr: true
          expect(response.status).to eq(200)
          expect(user.user_auth_tokens.sole.authenticated_with_oauth).to eq(true)
        ensure
          Discourse.disable_readonly_mode(Discourse::STAFF_WRITES_ONLY_MODE_KEY)
        end

        it "challenges enrolled users even when local logins are disabled" do
          SiteSetting.enable_local_logins = false

          nonce = start_omniauth_challenge
          expect(user.user_auth_tokens).to be_empty

          verify_totp(nonce)
          expect(response.status).to eq(200)

          post "/auth/second-factor.json", params: { second_factor_nonce: nonce }, xhr: true
          expect(response.status).to eq(200)
          expect(user.user_auth_tokens.sole.authenticated_with_oauth).to eq(true)
        end

        it "allows verifying with a passkey on /session/2fa even when local logins are disabled" do
          SiteSetting.enable_passkeys = true
          SiteSetting.enable_local_logins = false
          user.create_or_fetch_secure_identifier
          Fabricate(
            :user_security_key,
            user: user,
            credential_id: valid_passkey_data[:credential_id],
            public_key: valid_passkey_data[:public_key],
            factor_type: UserSecurityKey.factor_types[:first_factor],
          )
          DiscourseWebauthn.stubs(:origin).returns("http://localhost:3000")
          simulate_localhost_passkey_challenge

          nonce = start_omniauth_challenge
          get "/session/2fa.json", params: { nonce: }
          expect(response).to have_http_status(:ok)
          expect(response.parsed_body).to include(
            "passkeys_enabled" => true,
            "passkey_allowed_credential_ids" => [valid_passkey_data[:credential_id]],
          )

          post "/session/2fa.json",
               params: {
                 nonce:,
                 second_factor_method: UserSecondFactor.methods[:passkey],
                 second_factor_token: valid_passkey_auth_data,
               },
               xhr: true
          expect(response).to have_http_status(:ok)
          expect(response.parsed_body["ok"]).to eq(true)

          post "/auth/second-factor.json", params: { second_factor_nonce: nonce }, xhr: true
          expect(response).to have_http_status(:ok)
          expect(user.user_auth_tokens.sole.authenticated_with_oauth).to eq(true)
        end

        it "activates unapproved users and queues approval only after the challenge" do
          Jobs.run_immediately!
          SiteSetting.must_approve_users = true
          user.reload.update!(active: false, approved: false)

          nonce = start_omniauth_challenge
          expect(user.reload).to have_attributes(active: false, email_confirmed?: false)
          expect(ReviewableUser.pending.where(target: user)).to be_empty

          verify_totp(nonce)
          expect(response.status).to eq(200)

          post "/auth/second-factor.json", params: { second_factor_nonce: nonce }, xhr: true
          expect(response.status).to eq(403)
          expect(response.parsed_body["errors"]).to include(I18n.t("login.not_approved"))
          expect(user.reload).to have_attributes(active: true, email_confirmed?: true)
          expect(ReviewableUser.pending.where(target: user)).to exist
          expect(user.user_auth_tokens).to be_empty
        end

        it "rejects a pending continuation after entering full read-only mode" do
          nonce = start_omniauth_challenge
          verify_totp(nonce)
          expect(response.status).to eq(200)

          Discourse.enable_readonly_mode
          post "/auth/second-factor.json", params: { second_factor_nonce: nonce }, xhr: true
          expect(response.status).to eq(503)
          expect(user.user_auth_tokens).to be_empty
        ensure
          Discourse.disable_readonly_mode
        end
      end

      context "when user has TOTP enabled but enforce_second_factor_on_external_auth is false" do
        before { user.create_totp(enabled: true) }

        it "authenticates without TOTP when external authentication is exempt" do
          SiteSetting.enforce_second_factor_on_external_auth = false
          get "/auth/google_oauth2/callback.json"

          expect(response.status).to eq(302)

          data = JSON.parse(cookies[:authentication_data])

          expect(data["authenticated"]).to eq(true)
        end

        it "activates unapproved users and queues approval when external auth 2FA is disabled" do
          Jobs.run_immediately!
          SiteSetting.enforce_second_factor_on_external_auth = false
          SiteSetting.must_approve_users = true
          user.reload.update!(active: false, approved: false)

          get "/auth/google_oauth2/callback"
          expect(response).to redirect_to("/")
          expect(JSON.parse(cookies[:authentication_data])).to include("awaiting_approval" => true)
          expect(user.reload).to have_attributes(active: true, email_confirmed?: true)
          expect(ReviewableUser.pending.where(target: user)).to exist
          expect(user.user_auth_tokens).to be_empty
        end
      end

      it "does not treat a passkey-only registration as second-factor enrollment" do
        SiteSetting.enable_passkeys = true
        SiteSetting.allow_passkeys_for_2fa = true
        Fabricate(:passkey_with_random_credential, user:)

        get "/auth/google_oauth2/callback"
        expect(response).to redirect_to("/")
        expect(user.user_auth_tokens.sole.authenticated_with_oauth).to eq(true)
      end

      it "offers security keys in the native challenge for a security-key-only account" do
        Fabricate(:user_security_key_with_random_credential, user: user)

        get "/auth/google_oauth2/callback"
        location = URI(response.location)
        expect(location.path).to eq("/session/2fa")
        get "#{location.path}.json?#{location.query}"
        expect(response.parsed_body).to include(
          "security_keys_enabled" => true,
          "totp_enabled" => false,
        )
        expect(user.user_auth_tokens).to be_empty
      end

      it "activates unapproved users and queues approval without 2FA" do
        Jobs.run_immediately!
        SiteSetting.must_approve_users = true
        user.reload.update!(active: false, approved: false)

        get "/auth/google_oauth2/callback"
        expect(response).to redirect_to("/")
        expect(JSON.parse(cookies[:authentication_data])).to include("awaiting_approval" => true)
        expect(user.reload).to have_attributes(active: true, email_confirmed?: true)
        expect(ReviewableUser.pending.where(target: user)).to exist
        expect(user.user_auth_tokens).to be_empty
      end

      it "challenges and completes OAuth login for a backup-codes-only user" do
        backup_code = user.generate_backup_codes.first

        get "/auth/google_oauth2/callback"
        location = URI(response.location)
        expect(location.path).to eq("/session/2fa")
        nonce = Rack::Utils.parse_query(location.query).fetch("nonce")
        expect(user.user_auth_tokens).to be_empty

        post "/session/2fa.json",
             params: {
               nonce:,
               second_factor_method: UserSecondFactor.methods[:backup_codes],
               second_factor_token: backup_code,
             },
             xhr: true
        expect(response.status).to eq(200)

        post response.parsed_body.fetch("callback_path"),
             params: {
               second_factor_nonce: nonce,
             },
             xhr: true
        expect(response.status).to eq(200)
        expect(user.user_auth_tokens.sole.authenticated_with_oauth).to eq(true)
      end

      context "when sso_payload cookie exist" do
        before do
          SiteSetting.enable_discourse_connect_provider = true
          SiteSetting.discourse_connect_secret = "topsecret"
          SiteSetting.discourse_connect_provider_secrets =
            "somewhere.over.rainbow|#{SiteSetting.discourse_connect_secret}"

          @sso = DiscourseConnectBase.new
          @sso.nonce = "mynonce"
          @sso.sso_secret = SiteSetting.discourse_connect_secret
          @sso.return_sso_url = "http://somewhere.over.rainbow/sso"
          cookies[:sso_payload] = @sso.payload

          provider_uid = 12_345
          UserAssociatedAccount.create!(
            provider_name: "google_oauth2",
            provider_uid: provider_uid,
            user: user,
          )

          mock_auth(user.email, nil, nil, provider_uid)
        end

        it "sets the SSO provider destination from the payload cookie" do
          get "/auth/google_oauth2/callback.json"

          expect(response.status).to eq(302)

          data = JSON.parse(cookies[:authentication_data])

          expect(data["destination_url"]).to match(%r{/session/sso_provider\?sso\=.*\&sig\=.*})
        end

        it "hands off directly to the relying site without prompting twice when require_2fa is enabled" do
          totp = user.create_totp(enabled: true)
          @sso.require_2fa = true
          cookies[:sso_payload] = @sso.payload

          get "/auth/google_oauth2/callback"
          nonce = Rack::Utils.parse_query(URI(response.location).query).fetch("nonce")

          post "/session/2fa.json",
               params: {
                 nonce:,
                 second_factor_method: UserSecondFactor.methods[:totp],
                 second_factor_token: totp.totp_object.now,
               },
               xhr: true
          expect(response.status).to eq(200)

          post "/auth/second-factor.json", params: { second_factor_nonce: nonce }, xhr: true
          expect(response.status).to eq(200)
          redirect_url = response.parsed_body.fetch("redirect_url")
          expect(redirect_url).to start_with("/session/sso_provider?")

          get redirect_url
          expect(response.status).to eq(302)
          expect(response.location).to start_with("http://somewhere.over.rainbow/sso?")
          result = DiscourseConnectBase.parse(URI(response.location).query, "topsecret")
          expect(result.confirmed_2fa).to eq(true)

          # Reusing the same provider URL cannot replay the single-use login 2FA proof.
          get redirect_url
          expect(response.status).to eq(302)
          expect(URI(response.location).path).to eq("/session/2fa")
        end

        it "still prompts on the provider when the login challenge used a backup code" do
          user.create_totp(enabled: true)
          backup_code = user.generate_backup_codes.first
          @sso.require_2fa = true
          cookies[:sso_payload] = @sso.payload

          get "/auth/google_oauth2/callback"
          nonce = Rack::Utils.parse_query(URI(response.location).query).fetch("nonce")

          post "/session/2fa.json",
               params: {
                 nonce:,
                 second_factor_method: UserSecondFactor.methods[:backup_codes],
                 second_factor_token: backup_code,
               },
               xhr: true
          expect(response.status).to eq(200)

          post "/auth/second-factor.json", params: { second_factor_nonce: nonce }, xhr: true
          expect(response.status).to eq(200)
          redirect_url = response.parsed_body.fetch("redirect_url")

          get redirect_url
          expect(response.status).to eq(302)
          expect(URI(response.location).path).to eq("/session/2fa")
        end

        it "still prompts on the provider when enforce_second_factor_on_external_auth is false" do
          SiteSetting.enforce_second_factor_on_external_auth = false
          user.create_totp(enabled: true)
          @sso.require_2fa = true
          cookies[:sso_payload] = @sso.payload

          get "/auth/google_oauth2/callback"
          redirect_url = URI(response.location).request_uri
          expect(redirect_url).to start_with("/session/sso_provider?")

          get redirect_url
          expect(response.status).to eq(302)
          expect(URI(response.location).path).to eq("/session/2fa")
        end
      end

      context "when user has not verified his email" do
        before do
          provider_uid = "12345"
          UserAssociatedAccount.create!(
            provider_name: "google_oauth2",
            provider_uid: provider_uid,
            user: user,
          )
          user.update!(active: false)

          another_email = "another_email@test.com"
          mock_auth(another_email, nil, nil, provider_uid)
        end

        it "keeps the user awaiting activation when their email is unverified" do
          get "/auth/google_oauth2/callback.json"

          expect(response.status).to eq(302)

          data = JSON.parse(cookies[:authentication_data])

          expect(user.reload.active).to eq(false)
          expect(data["authenticated"]).to eq(false)
          expect(data["awaiting_activation"]).to eq(true)
        end
      end

      it "doesn't attempt redirect to external origin" do
        post "/auth/google_oauth2?origin=https://example.com/external"
        get "/auth/google_oauth2/callback"

        expect(response.status).to eq 302
        expect(response.location).to eq "http://test.localhost/"

        cookie_data = JSON.parse(response.cookies["authentication_data"])
        expect(cookie_data["destination_url"]).to eq("/")
      end

      it "redirects to internal origin" do
        post "/auth/google_oauth2?origin=http://test.localhost/t/123"
        get "/auth/google_oauth2/callback"

        expect(response.status).to eq 302
        expect(response.location).to eq "http://test.localhost/t/123"

        cookie_data = JSON.parse(response.cookies["authentication_data"])
        expect(cookie_data["destination_url"]).to eq("/t/123")
      end

      it "redirects to internal origin on subfolder" do
        set_subfolder "/subpath"

        post "/auth/google_oauth2?origin=http://test.localhost/subpath/t/123"
        get "/auth/google_oauth2/callback"

        expect(response.status).to eq 302
        expect(response.location).to eq "http://test.localhost/subpath/t/123"

        cookie_data = JSON.parse(response.cookies["authentication_data"])
        expect(cookie_data["destination_url"]).to eq("/subpath/t/123")
      end

      it "never redirects to /auth/ origin" do
        post "/auth/google_oauth2?origin=http://test.localhost/auth/google_oauth2"
        get "/auth/google_oauth2/callback"

        expect(response.status).to eq 302
        expect(response.location).to eq "http://test.localhost/"

        cookie_data = JSON.parse(response.cookies["authentication_data"])
        expect(cookie_data["destination_url"]).to eq("/")
      end

      it "never redirects to /auth/ origin on subfolder" do
        set_subfolder "/subpath"

        post "/auth/google_oauth2?origin=http://test.localhost/subpath/auth/google_oauth2"
        get "/auth/google_oauth2/callback"

        expect(response.status).to eq 302
        expect(response.location).to eq "http://test.localhost/subpath"

        cookie_data = JSON.parse(response.cookies["authentication_data"])
        expect(cookie_data["destination_url"]).to eq("/subpath")
      end

      it "redirects to relative origin" do
        post "/auth/google_oauth2?origin=/t/123"
        get "/auth/google_oauth2/callback"

        expect(response.status).to eq 302
        expect(response.location).to eq "http://test.localhost/t/123"

        cookie_data = JSON.parse(response.cookies["authentication_data"])
        expect(cookie_data["destination_url"]).to eq("/t/123")
      end

      it "redirects with query" do
        post "/auth/google_oauth2?origin=/t/123?foo=bar"
        get "/auth/google_oauth2/callback"

        expect(response.status).to eq 302
        expect(response.location).to eq "http://test.localhost/t/123?foo=bar"

        cookie_data = JSON.parse(response.cookies["authentication_data"])
        expect(cookie_data["destination_url"]).to eq("/t/123?foo=bar")
      end

      it "removes authentication_data cookie on logout" do
        post "/auth/google_oauth2?origin=https://example.com/external"
        get "/auth/google_oauth2/callback"

        provider = log_in_user(Fabricate(:user))

        expect(cookies["authentication_data"]).to be

        log_out_user(provider)

        expect(cookies["authentication_data"]).to be_nil
      end

      it "removes disallowed characters from username" do
        username = "strange_name*&^"
        fixed_username = "strange_name"

        mock_auth("user.with.strange.username@gmail.com", username)

        get "/auth/google_oauth2/callback.json"
        data = JSON.parse(cookies[:authentication_data])

        expect(data["username"]).to eq(fixed_username)
      end

      context "when groups are enabled" do
        let(:private_key) { OpenSSL::PKey::RSA.generate(2048) }
        let(:group1) { { id: "12345", name: "group1" } }
        let(:group2) { { id: "67890", name: "group2" } }
        let(:uid) { "12345" }
        let(:token) { "1245678" }
        let(:domain) { "mydomain.com" }

        def mock_omniauth_for_groups(groups)
          mock_auth = OmniAuth.config.mock_auth[:google_oauth2]
          OmniAuth.config.mock_auth[:google_oauth2] = mock_auth
          Rails.application.env_config["omniauth.auth"] = mock_auth

          SiteSetting.google_oauth2_hd_groups_service_account_admin_email = "admin@example.com"
          SiteSetting.google_oauth2_hd_groups_service_account_json = {
            "private_key" => private_key.to_s,
            :client_email => "discourse-group-sync@example.iam.gserviceaccount.com",
          }.to_json
          SiteSetting.google_oauth2_hd_groups = true

          stub_request(:post, "https://oauth2.googleapis.com/token").to_return do |request|
            {
              status: 200,
              body: { "access_token" => token, "type" => "bearer" }.to_json,
              headers: {
                "Content-Type" => "application/json",
              },
            }
          end

          stub_request(
            :get,
            "https://admin.googleapis.com/admin/directory/v1/groups?userKey=#{mock_auth.uid}",
          )
            .with(headers: { "Authorization" => "Bearer #{token}" })
            .to_return do
              {
                status: 200,
                body: { groups: groups }.to_json,
                headers: {
                  "Content-Type" => "application/json",
                },
              }
            end
        end

        before do
          SiteSetting.google_oauth2_hd = domain
          SiteSetting.google_oauth2_hd_groups_service_account_admin_email = "test@example.com"
          SiteSetting.google_oauth2_hd_groups_service_account_json = "{}"
          SiteSetting.google_oauth2_hd_groups = true
        end

        it "updates associated groups" do
          mock_omniauth_for_groups([group1, group2])
          get "/auth/google_oauth2/callback.json", params: { code: "abcde", hd: domain }
          expect(response.status).to eq(302)

          associated_groups = AssociatedGroup.where(provider_name: "google_oauth2")
          expect(associated_groups.length).to eq(2)
          expect(associated_groups.exists?(name: group1[:name])).to eq(true)
          expect(associated_groups.exists?(name: group2[:name])).to eq(true)

          user_associated_groups = UserAssociatedGroup.where(user_id: user.id)
          expect(user_associated_groups.length).to eq(2)
          expect(
            user_associated_groups.exists?(associated_group_id: associated_groups.first.id),
          ).to eq(true)
          expect(
            user_associated_groups.exists?(associated_group_id: associated_groups.second.id),
          ).to eq(true)

          mock_omniauth_for_groups([group1])
          get "/auth/google_oauth2/callback.json", params: { code: "abcde", hd: domain }
          expect(response.status).to eq(302)

          user_associated_groups = UserAssociatedGroup.where(user_id: user.id)
          expect(user_associated_groups.length).to eq(1)
          expect(
            user_associated_groups.exists?(associated_group_id: associated_groups.first.id),
          ).to eq(true)
          expect(
            user_associated_groups.exists?(associated_group_id: associated_groups.second.id),
          ).to eq(false)

          mock_omniauth_for_groups([])
          get "/auth/google_oauth2/callback.json", params: { code: "abcde", hd: domain }
          expect(response.status).to eq(302)

          user_associated_groups = UserAssociatedGroup.where(user_id: user.id)
          expect(user_associated_groups.length).to eq(0)
          expect(
            user_associated_groups.exists?(associated_group_id: associated_groups.first.id),
          ).to eq(false)
          expect(
            user_associated_groups.exists?(associated_group_id: associated_groups.second.id),
          ).to eq(false)
        end

        it "handles failure to retrieve groups" do
          mock_omniauth_for_groups([])

          get "/auth/google_oauth2/callback.json", params: { code: "abcde", hd: domain }

          expect(response.status).to eq(302)

          associated_groups = AssociatedGroup.where(provider_name: "google_oauth2")
          expect(associated_groups.exists?).to eq(false)
        end
      end
    end

    context "when attempting reconnect" do
      fab!(:user2, :user)
      let(:user1_provider_id) { "12345" }
      let(:user2_provider_id) { "123456" }

      before do
        UserAssociatedAccount.create!(
          provider_name: "google_oauth2",
          provider_uid: user1_provider_id,
          user: user,
        )
        UserAssociatedAccount.create!(
          provider_name: "google_oauth2",
          provider_uid: user2_provider_id,
          user: user2,
        )

        mock_auth("someother_email@test.com", nil, nil, user1_provider_id)
      end

      it "does not reconnect through the normal callback" do
        # Log in normally
        post "/auth/google_oauth2"
        expect(response.status).to eq(302)
        expect(session[:auth_reconnect]).to eq(false)

        get "/auth/google_oauth2/callback.json"
        expect(response.status).to eq(302)
        expect(session[:current_user_id]).to eq(user.id)

        # Log into another user
        OmniAuth.config.mock_auth[:google_oauth2].uid = user2_provider_id
        post "/auth/google_oauth2"
        expect(response.status).to eq(302)
        expect(session[:auth_reconnect]).to eq(false)

        get "/auth/google_oauth2/callback.json"
        expect(response.status).to eq(302)
        expect(session[:current_user_id]).to eq(user2.id)
        expect(UserAssociatedAccount.count).to eq(2)
      end

      it "redirects to the association URL when supplied" do
        # Log in normally
        post "/auth/google_oauth2?reconnect=true"
        expect(response.status).to eq(302)
        expect(session[:auth_reconnect]).to eq(true)

        get "/auth/google_oauth2/callback.json"
        expect(response.status).to eq(302)
        expect(session[:current_user_id]).to eq(user.id)

        # Clear cookie after login
        expect(session[:auth_reconnect]).to eq(nil)

        # Disconnect
        UserAssociatedAccount.find_by(user_id: user.id).destroy

        # Reconnect is account linking, not a new login.
        user.create_totp(enabled: true)
        post "/auth/google_oauth2?reconnect=true"
        expect(response.status).to eq(302)
        expect(session[:auth_reconnect]).to eq(true)

        OmniAuth.config.mock_auth[:google_oauth2].uid = user2_provider_id
        get "/auth/google_oauth2/callback.json"
        expect(response.status).to eq(302)
        expect(response.redirect_url).to start_with("http://test.localhost/associate/")

        expect(session[:current_user_id]).to eq(user.id)
        expect(UserAssociatedAccount.count).to eq(1) # Reconnect has not yet happened
      end

      it 'stores and redirects to \'origin\' parameter' do
        # Log in normally
        post "/auth/google_oauth2?origin=http://test.localhost/atesturl"
        expect(response.status).to eq(302)
        expect(request.server_session[:destination_url]).to eq("http://test.localhost/atesturl")

        get "/auth/google_oauth2/callback.json"
        expect(response.status).to eq(302)
        expect(response.redirect_url).to eq("http://test.localhost/atesturl")
      end
    end

    context "when confirming an existing session" do
      fab!(:other_user, :user)
      let(:user_provider_id) { "12345" }
      let(:other_provider_id) { "99999" }

      before do
        UserAssociatedAccount.create!(
          provider_name: "google_oauth2",
          provider_uid: user_provider_id,
          user: user,
        )
        UserAssociatedAccount.create!(
          provider_name: "google_oauth2",
          provider_uid: other_provider_id,
          user: other_user,
        )
        mock_auth(user.email, "Test User", "testuser", user_provider_id)
      end

      it "confirms the session and redirects back to origin without replacing the auth token" do
        sign_in(user)
        original_token = user.user_auth_tokens.sole

        post "/auth/google_oauth2",
             params: {
               confirm_session: true,
               origin: "/u/#{user.username}/preferences/second-factor",
             }
        expect(response.status).to eq(302)

        expect { get "/auth/google_oauth2/callback" }.not_to change { UserAuthToken.count }

        expect(response).to redirect_to("/u/#{user.username}/preferences/second-factor")
        expect(cookies[:authentication_data]).to be_nil
        expect(user.user_auth_tokens.sole.id).to eq(original_token.id)

        get "/u/trusted-session.json"
        expect(response.parsed_body["success"]).to eq("OK")

        post "/u/second_factors.json"
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["unconfirmed_session"]).to be_nil
        expect(response.parsed_body["totps"]).to eq([])
      end

      it "works when local logins are disabled" do
        SiteSetting.enable_local_logins = false
        sign_in(user)

        post "/auth/google_oauth2",
             params: {
               confirm_session: true,
               origin: "/u/#{user.username}/preferences/security",
             }
        get "/auth/google_oauth2/callback"

        expect(response).to redirect_to("/u/#{user.username}/preferences/security")
        get "/u/trusted-session.json"
        expect(response.parsed_body["success"]).to eq("OK")
      end

      it "rejects a mismatched provider account without switching users or altering associations" do
        sign_in(user)
        OmniAuth.config.mock_auth[:google_oauth2].uid = other_provider_id
        OmniAuth.config.mock_auth[:google_oauth2].info.email = other_user.email

        post "/auth/google_oauth2",
             params: {
               confirm_session: true,
               origin: "/u/#{user.username}/preferences/security",
             }
        get "/auth/google_oauth2/callback"

        expect(response.status).to eq(200)
        expect(response.body).to include(
          CGI.escapeHTML(I18n.t("login.confirm_session_external_mismatch", provider: "Google")),
        )
        expect(session[:current_user_id]).to eq(user.id)
        expect(
          UserAssociatedAccount.find_by(
            provider_name: "google_oauth2",
            provider_uid: other_provider_id,
          ).user_id,
        ).to eq(other_user.id)

        get "/u/trusted-session.json"
        expect(response.parsed_body["failed"]).to eq("FAILED")
      end

      it "rejects a cross-provider callback" do
        enable_auth_provider(:facebook)
        OmniAuth.config.mock_auth[:facebook] = OmniAuth::AuthHash.new(
          provider: "facebook",
          uid: user_provider_id,
          info: OmniAuth::AuthHash::InfoHash.new(email: user.email),
        )
        Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:facebook]

        sign_in(user)
        post "/auth/google_oauth2", params: { confirm_session: true }
        get "/auth/facebook/callback"

        expect(response.status).to eq(200)
        expect(response.body).to include(I18n.t("login.confirm_session_external_failed"))

        get "/u/trusted-session.json"
        expect(response.parsed_body["failed"]).to eq("FAILED")
      ensure
        OmniAuth.config.mock_auth[:facebook] = nil
      end

      it "does not start session confirmation on GET requests and clears stale confirmation state on normal login" do
        sign_in(user)

        get "/auth/google_oauth2", params: { confirm_session: true }
        expect(request.server_session[Auth::SessionConfirmation::EXTERNAL_CONFIRM_KEY]).to be_nil

        post "/auth/google_oauth2", params: { confirm_session: true }
        expect(
          request.server_session[Auth::SessionConfirmation::EXTERNAL_CONFIRM_KEY],
        ).to be_present

        post "/auth/google_oauth2"
        expect(request.server_session[Auth::SessionConfirmation::EXTERNAL_CONFIRM_KEY]).to be_nil
      end

      it "refuses confirmation when the current user is suspended" do
        sign_in(user)
        post "/auth/google_oauth2", params: { confirm_session: true }
        user.update!(suspended_at: 1.minute.ago, suspended_till: 1.day.from_now)

        get "/auth/google_oauth2/callback"
        expect(response.status).to eq(200)
        expect(response.body).to include(I18n.t("login.confirm_session_external_failed"))
        expect(request.server_session[Auth::SessionConfirmation::CONFIRMED_SESSION_KEY]).to be_nil

        get "/u/trusted-session.json"
        expect(response.status).to eq(403)
      end
    end

    context "after changing email" do
      def login(identity)
        mock_auth(identity[:email], nil, nil, "123545#{identity[:username]}")

        get "/auth/google_oauth2/callback.json"
        expect(response.status).to eq(302)
        JSON.parse(cookies[:authentication_data])
      end

      it "activates the correct email" do
        old_email = "old@email.com"
        old_identity = { name: "Bob", username: "bob", email: old_email }
        user = Fabricate(:user, email: old_email)
        new_email = "new@email.com"
        new_identity = { name: "Bob", username: "boguslaw", email: new_email }

        updater = EmailUpdater.new(guardian: user.guardian, user: user)
        updater.change_to(new_email)

        user.reload
        expect(user.email).to eq(old_email)

        response = login(old_identity)
        expect(response["authenticated"]).to eq(true)

        user.reload
        expect(user.email).to eq(old_email)

        delete "/session/#{user.username}" # log out

        response = login(new_identity)
        expect(response["authenticated"]).to eq(nil)
        expect(response["email"]).to eq(new_email)
      end
    end

    context "when user is staged" do
      fab!(:staged_user) do
        Fabricate(:user, username: "staged_user", email: "staged.user@gmail.com", staged: true)
      end

      it "keeps the staged user's username when the payload omits it" do
        mock_auth(staged_user.email, nil)

        get "/auth/google_oauth2/callback.json"
        data = JSON.parse(cookies[:authentication_data])

        expect(data["username"]).to eq(staged_user.username)
      end

      it "keeps the staged user's username when the payload matches it" do
        # it's important to check this, because we had regressions
        # when usernames were changed to the same username with "1" added at the end

        mock_auth(staged_user.email, staged_user.username)

        get "/auth/google_oauth2/callback.json"
        data = JSON.parse(cookies[:authentication_data])

        expect(data["username"]).to eq(staged_user.username)
      end

      it "updates the staged user's username when the payload supplies a new one" do
        new_username = "new_username"
        mock_auth(staged_user.email, new_username)

        get "/auth/google_oauth2/callback.json"
        data = JSON.parse(cookies[:authentication_data])

        expect(data["username"]).to eq(new_username)
      end
    end

    def mock_auth(email, nickname = nil, name = nil, uid = "12345")
      OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
        provider: "google_oauth2",
        uid: uid,
        info: OmniAuth::AuthHash::InfoHash.new(email: email, nickname: nickname, name: name),
        extra: {
          raw_info: OmniAuth::AuthHash.new(email_verified: true),
        },
      )

      Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2]
    end
  end

  describe "when the matched user is suspended" do
    fab!(:user) { Fabricate(:user, username: "mallory", name: "Old Name", active: false) }

    before do
      Fabricate(
        :user_associated_account,
        user: user,
        provider_name: "twitter",
        provider_uid: "1234",
      )
      enable_auth_provider(:twitter)
      user.update!(suspended_at: Time.zone.now, suspended_till: 1.year.from_now)

      OmniAuth.config.mock_auth[:twitter] = OmniAuth::AuthHash.new(
        provider: "twitter",
        uid: "1234",
        info:
          OmniAuth::AuthHash::InfoHash.new(
            email: user.email,
            nickname: "provider_username",
            name: "Provider Name",
          ),
      )
      Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:twitter]
    end

    after do
      Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:twitter] = nil
    end

    it "refuses the login without activating the user, applying overrides or logging on" do
      SiteSetting.auth_overrides_name = true
      SiteSetting.auth_overrides_username = true

      expect { get "/auth/twitter/callback.json" }.not_to change { UserAuthToken.count }

      data = JSON.parse(cookies[:authentication_data])
      expect(data["suspended"]).to eq(true)
      expect(data["authenticated"]).to be_falsey
      expect(session[:current_user_id]).to be_nil

      user.reload
      expect(user.active).to eq(false)
      expect(user.name).to eq("Old Name")
      expect(user.username).to eq("mallory")
    end
  end

  describe "with a fake provider" do
    class FakeAuthenticator < Auth::ManagedAuthenticator
      class Strategy
        include OmniAuth::Strategy
        def other_phase
          [418, {}, ["I am a teapot"]]
        end
      end

      def name
        "fake"
      end

      def enabled?
        false
      end

      def register_middleware(omniauth)
        omniauth.provider Strategy, name: :fake
      end
    end

    let(:fake_auth_provider) { Auth::AuthProvider.new(authenticator: FakeAuthenticator.new) }

    before do
      DiscoursePluginRegistry.register_auth_provider(fake_auth_provider)
      OmniAuth.config.test_mode = false
    end

    after { DiscoursePluginRegistry.auth_providers.delete(fake_auth_provider) }

    it "does not run 'other_phase' for disabled auth methods" do
      get "/auth/fake/blah"
      expect(response.status).to eq(404)
    end

    it "does not leak 'other_phase' for disabled auth methods onto other methods" do
      get "/auth/twitter/blah"
      expect(response.status).to eq(404)
    end

    it "challenges and signs in a user returned by a registered plugin authenticator" do
      FakeAuthenticator.any_instance.stubs(:enabled?).returns(true)
      totp = user.create_totp(enabled: true)
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:fake] = OmniAuth::AuthHash.new(
        provider: "fake",
        uid: "external-id",
        info: {
          email: user.email,
        },
      )
      Fabricate(:user_associated_account, provider_name: "fake", provider_uid: "external-id", user:)

      get "/auth/fake/callback"
      location = URI(response.location)
      expect(location.path).to eq("/session/2fa")
      nonce = Rack::Utils.parse_query(location.query).fetch("nonce")
      expect(user.user_auth_tokens).to be_empty

      post "/session/2fa.json",
           params: {
             nonce:,
             second_factor_method: UserSecondFactor.methods[:totp],
             second_factor_token: totp.totp_object.now,
           },
           xhr: true
      expect(response.status).to eq(200)
      post response.parsed_body.fetch("callback_path"),
           params: {
             second_factor_nonce: nonce,
           },
           xhr: true
      expect(response.status).to eq(200)
      expect(user.user_auth_tokens.sole.authenticated_with_oauth).to eq(true)
    ensure
      OmniAuth.config.mock_auth[:fake] = nil
    end

    it "challenges and signs in when a ManagedAuthenticator matches a user without a UserAssociatedAccount" do
      FakeAuthenticator.any_instance.stubs(:enabled?).returns(true)
      totp = user.create_totp(enabled: true)
      auth_result = Auth::Result.new
      auth_result.user = user
      auth_result.email = user.email
      auth_result.email_valid = true
      auth_result.extra_data = { provider: "fake", uid: "external-no-assoc" }
      FakeAuthenticator.any_instance.stubs(:after_authenticate).returns(auth_result)

      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:fake] = OmniAuth::AuthHash.new(
        provider: "fake",
        uid: "external-no-assoc",
        info: {
          email: user.email,
        },
      )

      get "/auth/fake/callback"
      location = URI(response.location)
      expect(location.path).to eq("/session/2fa")
      nonce = Rack::Utils.parse_query(location.query).fetch("nonce")
      expect(user.user_associated_accounts).to be_empty
      expect(user.user_auth_tokens).to be_empty

      post "/session/2fa.json",
           params: {
             nonce:,
             second_factor_method: UserSecondFactor.methods[:totp],
             second_factor_token: totp.totp_object.now,
           },
           xhr: true
      expect(response.status).to eq(200)

      post response.parsed_body.fetch("callback_path"),
           params: {
             second_factor_nonce: nonce,
           },
           xhr: true
      expect(response.status).to eq(200)
      expect(user.user_auth_tokens.sole.authenticated_with_oauth).to eq(true)
    ensure
      OmniAuth.config.mock_auth[:fake] = nil
    end

    it "runs 'other_phase' for enabled auth methods" do
      FakeAuthenticator.any_instance.stubs(:enabled?).returns(true)
      get "/auth/fake/blah"
      expect(response.status).to eq(418)
    end
  end
end
