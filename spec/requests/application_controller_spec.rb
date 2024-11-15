# frozen_string_literal: true

RSpec.describe ApplicationController do
  describe "#redirect_to_login_if_required" do
    let(:admin) { Fabricate(:admin) }

    before do
      admin # to skip welcome wizard at home page `/`
      SiteSetting.login_required = true
    end

    it "should never cache a login redirect" do
      get "/"
      expect(response.headers["Cache-Control"]).to eq("no-cache, no-store")
    end

    it "should redirect to login normally" do
      get "/"
      expect(response).to redirect_to("/login")
    end

    it "should redirect to SSO if enabled" do
      SiteSetting.discourse_connect_url = "http://someurl.com"
      SiteSetting.enable_discourse_connect = true
      get "/"
      expect(response).to redirect_to("/session/sso")
    end

    it "should redirect to authenticator if only one, and local logins disabled" do
      # Local logins and google enabled, direct to login UI
      SiteSetting.enable_google_oauth2_logins = true
      get "/"
      expect(response).to redirect_to("/login")

      # Only google enabled, login immediately
      SiteSetting.enable_local_logins = false
      get "/"
      expect(response).to redirect_to("/auth/google_oauth2")

      # Google and GitHub enabled, direct to login UI
      SiteSetting.enable_github_logins = true
      get "/"
      expect(response).to redirect_to("/login")
    end

    it "should not redirect to SSO when auth_immediately is disabled" do
      SiteSetting.auth_immediately = false
      SiteSetting.discourse_connect_url = "http://someurl.com"
      SiteSetting.enable_discourse_connect = true

      get "/"
      expect(response).to redirect_to("/login")
    end

    it "should not redirect to authenticator when auth_immediately is disabled" do
      SiteSetting.auth_immediately = false
      SiteSetting.enable_google_oauth2_logins = true
      SiteSetting.enable_local_logins = false

      get "/"
      expect(response).to redirect_to("/login")
    end

    context "with omniauth in test mode" do
      before do
        OmniAuth.config.test_mode = true
        OmniAuth.config.add_mock(
          :google_oauth2,
          info: OmniAuth::AuthHash::InfoHash.new(email: "address@example.com"),
          extra: {
            raw_info: OmniAuth::AuthHash.new(email_verified: true, email: "address@example.com"),
          },
        )
        Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2]
      end

      after do
        Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[
          :google_oauth2
        ] = nil
        OmniAuth.config.test_mode = false
      end

      it "should not redirect to authenticator if registration in progress" do
        SiteSetting.enable_local_logins = false
        SiteSetting.enable_google_oauth2_logins = true

        get "/"
        expect(response).to redirect_to("/auth/google_oauth2")

        expect(cookies[:authentication_data]).to eq(nil)

        get "/auth/google_oauth2/callback.json"
        expect(response).to redirect_to("/")
        expect(cookies[:authentication_data]).not_to eq(nil)

        get "/"
        expect(response).to redirect_to("/login")
      end
    end

    it "contains authentication data when cookies exist" do
      cookie_data = "someauthenticationdata"
      cookies["authentication_data"] = cookie_data
      get "/login"
      expect(response.status).to eq(200)
      expect(response.body).to include("data-authentication-data=\"#{cookie_data}\"")
      expect(response.headers["Set-Cookie"]).to include("authentication_data=;") # Delete cookie
    end

    it "deletes authentication data cookie even if already authenticated" do
      sign_in(Fabricate(:user))
      cookies["authentication_data"] = "someauthenticationdata"
      get "/"
      expect(response.status).to eq(200)
      expect(response.body).not_to include("data-authentication-data=")
      expect(response.headers["Set-Cookie"]).to include("authentication_data=;") # Delete cookie
    end

    it "returns a 403 for json requests" do
      get "/latest"
      expect(response.status).to eq(302)

      get "/latest.json"
      expect(response.status).to eq(403)
    end
  end

  describe "#redirect_to_second_factor_if_required" do
    let(:admin) { Fabricate(:admin) }
    fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

    before do
      admin # to skip welcome wizard at home page `/`
    end

    it "should redirect admins when enforce_second_factor is 'all'" do
      SiteSetting.enforce_second_factor = "all"
      sign_in(admin)

      get "/"
      expect(response).to redirect_to("/u/#{admin.username}/preferences/second-factor")
    end

    it "should redirect users when enforce_second_factor is 'all'" do
      SiteSetting.enforce_second_factor = "all"
      sign_in(user)

      get "/"
      expect(response).to redirect_to("/u/#{user.username}/preferences/second-factor")
    end

    it "should redirect users when enforce_second_factor is 'all' and authenticated via oauth" do
      SiteSetting.enforce_second_factor = "all"
      sign_in(user)
      user.user_auth_tokens.last.update(authenticated_with_oauth: true)

      get "/"
      expect(response).to redirect_to("/u/#{user.username}/preferences/second-factor")
    end

    it "should not redirect users when enforce_second_factor is 'all', authenticated via oauth but enforce_second_factor_on_external_auth is false" do
      SiteSetting.enforce_second_factor = "all"
      SiteSetting.enforce_second_factor_on_external_auth = false
      sign_in(user)
      user.user_auth_tokens.last.update(authenticated_with_oauth: true)

      get "/"
      expect(response.status).to eq(200)
    end

    it "should not redirect anonymous users when enforce_second_factor is 'all'" do
      SiteSetting.enforce_second_factor = "all"
      SiteSetting.allow_anonymous_posting = true

      sign_in(user)

      post "/u/toggle-anon.json"
      expect(response.status).to eq(200)

      get "/"
      expect(response.status).to eq(200)
    end

    it "should redirect admins when enforce_second_factor is 'staff'" do
      SiteSetting.enforce_second_factor = "staff"
      sign_in(admin)

      get "/"
      expect(response).to redirect_to("/u/#{admin.username}/preferences/second-factor")
    end

    it "should not redirect users when enforce_second_factor is 'staff'" do
      SiteSetting.enforce_second_factor = "staff"
      sign_in(user)

      get "/"
      expect(response.status).to eq(200)
    end

    it "should not redirect admins when turned off" do
      SiteSetting.enforce_second_factor = "no"
      sign_in(admin)

      get "/"
      expect(response.status).to eq(200)
    end

    it "should not redirect users when turned off" do
      SiteSetting.enforce_second_factor = "no"
      sign_in(user)

      get "/"
      expect(response.status).to eq(200)
    end

    it "correctly redirects for Unicode usernames" do
      SiteSetting.enforce_second_factor = "all"
      SiteSetting.unicode_usernames = true
      user = sign_in(Fabricate(:unicode_user))

      get "/"
      expect(response).to redirect_to("/u/#{user.encoded_username}/preferences/second-factor")
    end

    context "when enforcing second factor for staff" do
      before do
        SiteSetting.enforce_second_factor = "staff"
        sign_in(admin)
      end

      context "when the staff member has not enabled TOTP or security keys" do
        it "redirects the staff to the second factor preferences" do
          get "/"
          expect(response).to redirect_to("/u/#{admin.username}/preferences/second-factor")
        end
      end

      context "when the staff member has enabled TOTP" do
        before { Fabricate(:user_second_factor_totp, user: admin) }

        it "does not redirects the staff to set up 2FA" do
          get "/"
          expect(response.status).to eq(200)
        end
      end

      context "when the staff member has enabled security keys" do
        before { Fabricate(:user_security_key_with_random_credential, user: admin) }

        it "does not redirects the staff to set up 2FA" do
          get "/"
          expect(response.status).to eq(200)
        end
      end
    end
  end

  describe "#redirect_to_profile_if_required" do
    fab!(:user)

    before { sign_in(user) }

    context "when the user is missing required custom fields" do
      before do
        Fabricate(:user_field, requirement: "for_all_users")
        UserRequiredFieldsVersion.create!
      end

      it "redirects the user to the profile preferences" do
        get "/hot"
        expect(response).to redirect_to("/u/#{user.username}/preferences/profile")
      end

      it "only logs user history once per day" do
        expect do
          RateLimiter.enable
          get "/hot"
          get "/hot"
        end.to change { UserHistory.count }.by(1)
      end
    end

    context "when the user has filled up all required custom fields" do
      before do
        Fabricate(:user_field, requirement: "for_all_users")
        UserRequiredFieldsVersion.create!
        user.bump_required_fields_version
      end

      it "redirects the user to the profile preferences" do
        get "/hot"
        expect(response).not_to redirect_to("/u/#{user.username}/preferences/profile")
      end
    end
  end

  describe "invalid request params" do
    before do
      @old_logger = Rails.logger
      @logs = StringIO.new
      Rails.logger = Logger.new(@logs)
    end

    after { Rails.logger = @old_logger }

    it "should not raise a 500 (nor should it log a warning) for bad params" do
      bad_str = (+"d\xDE").force_encoding("utf-8")
      expect(bad_str.valid_encoding?).to eq(false)

      get "/latest.json", params: { test: bad_str }

      expect(response.status).to eq(400)

      log = @logs.string

      if (log.include? "exception app middleware")
        # heisentest diagnostics
        puts
        puts "EXTRA DIAGNOSTICS FOR INTERMITTENT TEST FAIL"
        puts log
        puts ">> action_dispatch.exception"
        ex = request.env["action_dispatch.exception"]
        puts ">> exception class: #{ex.class} : #{ex}"
      end

      expect(log).not_to include("exception app middleware")

      expect(response.status).to eq(400)
    end
  end

  describe "missing required param" do
    it "should return a 400" do
      get "/search/query.json", params: { trem: "misspelled term" }

      expect(response.status).to eq(400)
      expect(response.parsed_body["errors"].first).to include(
        "param is missing or the value is empty: term",
      )
    end
  end

  describe "build_not_found_page" do
    describe "topic not found" do
      it "should not redirect to permalink if topic/category does not exist" do
        topic = create_post.topic
        Permalink.create!(
          url: topic.relative_url,
          permalink_type_value: topic.id + 1,
          permalink_type: "topic",
        )
        topic.trash!

        SiteSetting.detailed_404 = false
        get topic.relative_url
        expect(response.status).to eq(404)

        SiteSetting.detailed_404 = true
        get topic.relative_url
        expect(response.status).to eq(410)
      end

      it "should return permalink for deleted topics" do
        topic = create_post.topic
        external_url = "https://somewhere.over.rainbow"
        Permalink.create!(
          url: topic.relative_url,
          permalink_type_value: external_url,
          permalink_type: "external_url",
        )
        topic.trash!

        get topic.relative_url
        expect(response.status).to eq(301)
        expect(response).to redirect_to(external_url)

        get "/t/#{topic.id}.json"
        expect(response.status).to eq(301)
        expect(response).to redirect_to(external_url)

        get "/t/#{topic.id}.json", xhr: true
        expect(response.status).to eq(200)
        expect(response.body).to eq(external_url)
      end

      it "supports subfolder with permalinks" do
        set_subfolder "/forum"

        trashed_topic = create_post.topic
        trashed_topic.trash!
        new_topic = create_post.topic
        permalink =
          Permalink.create!(
            url: trashed_topic.relative_url,
            permalink_type_value: new_topic.id,
            permalink_type: "topic",
          )

        # no subfolder because router doesn't know about subfolder in this test
        get "/t/#{trashed_topic.slug}/#{trashed_topic.id}"
        expect(response.status).to eq(301)
        expect(response).to redirect_to("/forum/t/#{new_topic.slug}/#{new_topic.id}")

        permalink.destroy
        category = Fabricate(:category)
        permalink =
          Permalink.create!(
            url: trashed_topic.relative_url,
            permalink_type_value: category.id,
            permalink_type: "category",
          )
        get "/t/#{trashed_topic.slug}/#{trashed_topic.id}"
        expect(response.status).to eq(301)
        expect(response).to redirect_to("/forum/c/#{category.slug}/#{category.id}")

        permalink.destroy
        permalink =
          Permalink.create!(
            url: trashed_topic.relative_url,
            permalink_type_value: new_topic.posts.last.id,
            permalink_type: "post",
          )
        get "/t/#{trashed_topic.slug}/#{trashed_topic.id}"
        expect(response.status).to eq(301)
        expect(response).to redirect_to(
          "/forum/t/#{new_topic.slug}/#{new_topic.id}/#{new_topic.posts.last.post_number}",
        )
      end

      it "should return 404 and show Google search for an invalid topic route" do
        get "/t/nope-nope/99999999"

        expect(response.status).to eq(404)

        response_body = response.body

        expect(response_body).to include(I18n.t("page_not_found.search_button"))
        expect(response_body).to have_tag("input", with: { value: "nope nope" })
      end

      it "should not include Google search if login_required is enabled" do
        SiteSetting.login_required = true
        sign_in(Fabricate(:user))
        get "/t/nope-nope/99999999"
        expect(response.status).to eq(404)
        expect(response.body).to_not include("google.com/search")
      end

      describe "no logspam" do
        let(:fake_logger) { FakeLogger.new }

        before { Rails.logger.broadcast_to(fake_logger) }

        after { Rails.logger.stop_broadcasting_to(fake_logger) }

        it "should handle 404 to a css file" do
          Discourse.cache.delete("page_not_found_topics:#{I18n.locale}")

          topic1 = Fabricate(:topic)
          get "/stylesheets/mobile_1_4cd559272273fe6d3c7db620c617d596a5fdf240.css",
              headers: {
                "HTTP_ACCEPT" => "text/css,*/*,q=0.1",
              }
          expect(response.status).to eq(404)
          expect(response.body).to include(topic1.title)

          topic2 = Fabricate(:topic)
          get "/stylesheets/mobile_1_4cd559272273fe6d3c7db620c617d596a5fdf240.css",
              headers: {
                "HTTP_ACCEPT" => "text/css,*/*,q=0.1",
              }
          expect(response.status).to eq(404)
          expect(response.body).to include(topic1.title)
          expect(response.body).to_not include(topic2.title)

          expect(fake_logger.fatals.length).to eq(0)
          expect(fake_logger.errors.length).to eq(0)
          expect(fake_logger.warnings.length).to eq(0)
        end
      end

      it "should cache results" do
        Discourse.cache.delete("page_not_found_topics:#{I18n.locale}")
        Discourse.cache.delete("page_not_found_topics:fr")

        topic1 = Fabricate(:topic)
        get "/t/nope-nope/99999999"
        expect(response.status).to eq(404)
        expect(response.body).to include(topic1.title)

        topic2 = Fabricate(:topic)
        get "/t/nope-nope/99999999"
        expect(response.status).to eq(404)
        expect(response.body).to include(topic1.title)
        expect(response.body).to_not include(topic2.title)

        # Different locale should have different cache
        SiteSetting.default_locale = :fr
        get "/t/nope-nope/99999999"
        expect(response.status).to eq(404)
        expect(response.body).to include(topic1.title)
        expect(response.body).to include(topic2.title)
      end
    end
  end

  describe "#handle_theme" do
    let!(:theme) { Fabricate(:theme, user_selectable: true) }
    let!(:theme2) { Fabricate(:theme, user_selectable: true) }
    let!(:non_selectable_theme) { Fabricate(:theme, user_selectable: false) }
    fab!(:user)
    fab!(:admin)

    before { sign_in(user) }

    it "selects the theme the user has selected" do
      user.user_option.update_columns(theme_ids: [theme.id])

      get "/"
      expect(response.status).to eq(200)
      expect(controller.theme_id).to eq(theme.id)

      theme.update_attribute(:user_selectable, false)

      get "/"
      expect(response.status).to eq(200)
      expect(controller.theme_id).to eq(SiteSetting.default_theme_id)
    end

    it "can be overridden with a cookie" do
      user.user_option.update_columns(theme_ids: [theme.id])

      cookies["theme_ids"] = "#{theme2.id}|#{user.user_option.theme_key_seq}"

      get "/"
      expect(response.status).to eq(200)
      expect(controller.theme_id).to eq(theme2.id)
    end

    it "falls back to the default theme when the user has no cookies or preferences" do
      user.user_option.update_columns(theme_ids: [])
      cookies["theme_ids"] = nil
      theme2.set_default!

      get "/"
      expect(response.status).to eq(200)
      expect(controller.theme_id).to eq(theme2.id)
    end

    it "can be overridden with preview_theme_id param" do
      sign_in(admin)
      cookies["theme_ids"] = "#{theme.id}|#{admin.user_option.theme_key_seq}"

      get "/", params: { preview_theme_id: theme2.id }
      expect(response.status).to eq(200)
      expect(controller.theme_id).to eq(theme2.id)

      get "/", params: { preview_theme_id: non_selectable_theme.id }
      expect(controller.theme_id).to eq(non_selectable_theme.id)
    end

    it "does not allow non privileged user to preview themes" do
      sign_in(user)
      get "/", params: { preview_theme_id: non_selectable_theme.id }
      expect(controller.theme_id).to eq(SiteSetting.default_theme_id)
    end

    it "cookie can fail back to user if out of sync" do
      user.user_option.update_columns(theme_ids: [theme.id])
      cookies["theme_ids"] = "#{theme2.id}|#{user.user_option.theme_key_seq - 1}"

      get "/"
      expect(response.status).to eq(200)
      expect(controller.theme_id).to eq(theme.id)
    end
  end

  describe "Custom hostname" do
    it "does not allow arbitrary host injection" do
      get("/latest", headers: { "X-Forwarded-Host" => "test123.com" })

      expect(response.body).not_to include("test123")
    end
  end

  describe "allow_embedding_site_in_an_iframe" do
    it "should have the 'X-Frame-Options' header with value 'sameorigin'" do
      get("/latest")
      expect(response.headers["X-Frame-Options"]).to eq("SAMEORIGIN")
    end

    it "should not include the 'X-Frame-Options' header" do
      SiteSetting.allow_embedding_site_in_an_iframe = true
      get("/latest")
      expect(response.headers).not_to include("X-Frame-Options")
    end
  end

  describe "setting `Cross-Origin-Opener-Policy` header" do
    describe "when `cross_origin_opener_policy_header` site setting is set to `same-origin`" do
      before { SiteSetting.cross_origin_opener_policy_header = "same-origin" }

      it "sets `Cross-Origin-Opener-Policy` header to `same-origin`" do
        get "/latest"

        expect(response.status).to eq(200)
        expect(response.headers["Cross-Origin-Opener-Policy"]).to eq("same-origin")
      end

      it "does not set the `Cross-Origin-Opener-Policy` header for a JSON request" do
        get "/latest.json"

        expect(response.status).to eq(200)
        expect(response.headers["Cross-Origin-Opener-Policy"]).to eq(nil)
      end
    end

    describe "when `cross_origin_opener_policy_header` site setting is set to `unsafe-none`" do
      it "does not set the `Cross-Origin-Opener-Policy` header" do
        SiteSetting.cross_origin_opener_policy_header = "unsafe-none"

        get "/latest"

        expect(response.status).to eq(200)
        expect(response.headers["Cross-Origin-Opener-Policy"]).to eq("unsafe-none")
      end
    end

    describe "when `cross_origin_opener_unsafe_none_groups` site setting has been set" do
      fab!(:group)
      fab!(:current_user) { Fabricate(:user) }

      before do
        SiteSetting.cross_origin_opener_policy_header = "same-origin"
        SiteSetting.cross_origin_opener_unsafe_none_groups = group.id
      end

      context "for logged in user" do
        before { sign_in(current_user) }

        it "sets `Cross-Origin-Opener-Policy` to `unsafe-none` for a listed group" do
          group.add(current_user)

          get "/latest"

          expect(response.status).to eq(200)
          expect(response.headers["Cross-Origin-Opener-Policy"]).to eq("unsafe-none")
        end

        it "sets `Cross-Origin-Opener-Policy` to configured value when group is missing" do
          get "/latest"

          expect(response.status).to eq(200)
          expect(response.headers["Cross-Origin-Opener-Policy"]).to eq("same-origin")
        end
      end

      context "for anon" do
        it "sets `Cross-Origin-Opener-Policy` to configured value" do
          get "/latest"

          expect(response.status).to eq(200)
          expect(response.headers["Cross-Origin-Opener-Policy"]).to eq("same-origin")
        end
      end
    end
  end

  describe "splash_screen" do
    let(:admin) { Fabricate(:admin) }

    before { admin }

    it "adds a preloader splash screen when enabled" do
      get "/"

      expect(response.status).to eq(200)
      expect(response.body).to include("d-splash")

      SiteSetting.splash_screen = false

      get "/"

      expect(response.status).to eq(200)
      expect(response.body).not_to include("d-splash")
    end
  end

  describe "Delegated auth" do
    let :public_key do
      <<~TXT
      -----BEGIN PUBLIC KEY-----
      MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDh7BS7Ey8hfbNhlNAW/47pqT7w
      IhBz3UyBYzin8JurEQ2pY9jWWlY8CH147KyIZf1fpcsi7ZNxGHeDhVsbtUKZxnFV
      p16Op3CHLJnnJKKBMNdXMy0yDfCAHZtqxeBOTcCo1Vt/bHpIgiK5kmaekyXIaD0n
      w0z/BYpOgZ8QwnI5ZwIDAQAB
      -----END PUBLIC KEY-----
      TXT
    end

    let :args do
      { auth_redirect: "http://no-good.com", user_api_public_key: "not-a-valid-public-key" }
    end

    it "disallows invalid public_key param" do
      args[:auth_redirect] = "discourse://auth_redirect"
      get "/latest", params: args

      expect(response.body).to eq(I18n.t("user_api_key.invalid_public_key"))
    end

    it "does not allow invalid auth_redirect" do
      args[:user_api_public_key] = public_key
      get "/latest", params: args

      expect(response.body).to eq(I18n.t("user_api_key.invalid_auth_redirect"))
    end

    it "does not redirect if one_time_password scope is disallowed" do
      SiteSetting.allow_user_api_key_scopes = "read|write"
      args[:user_api_public_key] = public_key
      args[:auth_redirect] = "discourse://auth_redirect"

      get "/latest", params: args

      expect(response.status).to_not eq(302)
      expect(response).to_not redirect_to("#{args[:auth_redirect]}?otp=true")
    end

    it "redirects correctly with valid params" do
      SiteSetting.login_required = true
      args[:user_api_public_key] = public_key
      args[:auth_redirect] = "discourse://auth_redirect"

      get "/categories", params: args

      expect(response.status).to eq(302)
      expect(response).to redirect_to("#{args[:auth_redirect]}?otp=true")
    end
  end

  describe "Content Security Policy" do
    it "is enabled by SiteSettings" do
      SiteSetting.content_security_policy = false
      SiteSetting.content_security_policy_report_only = false

      get "/"

      expect(response.headers).to_not include("Content-Security-Policy")
      expect(response.headers).to_not include("Content-Security-Policy-Report-Only")

      SiteSetting.content_security_policy = true
      SiteSetting.content_security_policy_report_only = true

      get "/"

      expect(response.headers).to include("Content-Security-Policy")
      expect(response.headers).to include("Content-Security-Policy-Report-Only")
    end

    it "can be customized with SiteSetting" do
      SiteSetting.content_security_policy = true

      get "/"
      script_src = parse(response.headers["Content-Security-Policy"])["script-src"]

      expect(script_src).to_not include("'unsafe-eval'")

      SiteSetting.content_security_policy_script_src = "'unsafe-eval'"

      get "/"
      script_src = parse(response.headers["Content-Security-Policy"])["script-src"]

      expect(script_src).to include("'unsafe-eval'")
    end

    it "does not set CSP when responding to non-HTML" do
      SiteSetting.content_security_policy = true
      SiteSetting.content_security_policy_report_only = true

      get "/latest.json"

      expect(response.headers).to_not include("Content-Security-Policy")
      expect(response.headers).to_not include("Content-Security-Policy-Report-Only")
    end

    it "when GTM is enabled it adds the same nonce to the policy and the GTM tag" do
      SiteSetting.content_security_policy = true
      SiteSetting.content_security_policy_report_only = true
      SiteSetting.gtm_container_id = "GTM-ABCDEF"

      get "/latest"

      script_src = parse(response.headers["Content-Security-Policy"])["script-src"]
      report_only_script_src =
        parse(response.headers["Content-Security-Policy-Report-Only"])["script-src"]

      nonce = extract_nonce_from_script_src(script_src)
      report_only_nonce = extract_nonce_from_script_src(report_only_script_src)

      expect(nonce).to eq(report_only_nonce)

      gtm_meta_tag = Nokogiri::HTML5.fragment(response.body).css("#data-google-tag-manager").first
      expect(gtm_meta_tag["data-nonce"]).to eq(nonce)
    end

    it "doesn't reuse nonces between requests" do
      global_setting :anon_cache_store_threshold, 1
      Middleware::AnonymousCache.enable_anon_cache
      Middleware::AnonymousCache.clear_all_cache!

      SiteSetting.content_security_policy = true
      SiteSetting.content_security_policy_report_only = true
      SiteSetting.gtm_container_id = "GTM-ABCDEF"

      get "/latest"

      expect(response.headers["X-Discourse-Cached"]).to eq("store")
      expect(response.headers).not_to include("Discourse-CSP-Nonce-Placeholder")

      script_src = parse(response.headers["Content-Security-Policy"])["script-src"]
      report_only_script_src =
        parse(response.headers["Content-Security-Policy-Report-Only"])["script-src"]

      first_nonce = extract_nonce_from_script_src(script_src)
      first_report_only_nonce = extract_nonce_from_script_src(report_only_script_src)

      expect(first_nonce).to eq(first_report_only_nonce)

      gtm_meta_tag = Nokogiri::HTML5.fragment(response.body).css("#data-google-tag-manager").first
      expect(gtm_meta_tag["data-nonce"]).to eq(first_nonce)

      get "/latest"

      expect(response.headers["X-Discourse-Cached"]).to eq("true")
      expect(response.headers).not_to include("Discourse-CSP-Nonce-Placeholder")

      script_src = parse(response.headers["Content-Security-Policy"])["script-src"]
      report_only_script_src =
        parse(response.headers["Content-Security-Policy-Report-Only"])["script-src"]

      second_nonce = extract_nonce_from_script_src(script_src)
      second_report_only_nonce = extract_nonce_from_script_src(report_only_script_src)

      expect(second_nonce).to eq(second_report_only_nonce)

      expect(first_nonce).not_to eq(second_nonce)
      gtm_meta_tag = Nokogiri::HTML5.fragment(response.body).css("#data-google-tag-manager").first
      expect(gtm_meta_tag["data-nonce"]).to eq(second_nonce)
    end

    def parse(csp_string)
      csp_string
        .split(";")
        .map do |policy|
          directive, *sources = policy.split
          [directive, sources]
        end
        .to_h
    end

    def extract_nonce_from_script_src(script_src)
      nonce = script_src.lazy.map { |src| src[/\A'nonce-([^']+)'\z/, 1] }.find(&:itself)
      expect(nonce).to be_present
      nonce
    end
  end

  it "can respond to a request with */* accept header" do
    get "/", headers: { HTTP_ACCEPT: "*/*" }
    expect(response.status).to eq(200)
    expect(response.body).to include("Discourse")
  end

  it "has canonical tag" do
    get "/", headers: { HTTP_ACCEPT: "*/*" }
    expect(response.body).to have_tag(
      "link",
      with: {
        rel: "canonical",
        href: "http://test.localhost/",
      },
    )
    get "/?query_param=true", headers: { HTTP_ACCEPT: "*/*" }
    expect(response.body).to have_tag(
      "link",
      with: {
        rel: "canonical",
        href: "http://test.localhost/",
      },
    )
    get "/latest?page=2&additional_param=true", headers: { HTTP_ACCEPT: "*/*" }
    expect(response.body).to have_tag(
      "link",
      with: {
        rel: "canonical",
        href: "http://test.localhost/latest?page=2",
      },
    )
    get "/404", headers: { HTTP_ACCEPT: "*/*" }
    expect(response.body).to have_tag(
      "link",
      with: {
        rel: "canonical",
        href: "http://test.localhost/404",
      },
    )
    topic = create_post.topic
    get "/t/#{topic.slug}/#{topic.id}"
    expect(response.body).to have_tag(
      "link",
      with: {
        rel: "canonical",
        href: "http://test.localhost/t/#{topic.slug}/#{topic.id}",
      },
    )
  end

  it "adds a noindex header if non-canonical indexing is disabled" do
    SiteSetting.allow_indexing_non_canonical_urls = false
    get "/"
    expect(response.headers["X-Robots-Tag"]).to be_nil

    get "/latest"
    expect(response.headers["X-Robots-Tag"]).to be_nil

    get "/categories"
    expect(response.headers["X-Robots-Tag"]).to be_nil

    topic = create_post.topic
    get "/t/#{topic.slug}/#{topic.id}"
    expect(response.headers["X-Robots-Tag"]).to be_nil
    post = create_post(topic_id: topic.id)
    get "/t/#{topic.slug}/#{topic.id}/2"
    expect(response.headers["X-Robots-Tag"]).to eq("noindex")

    20.times { create_post(topic_id: topic.id) }
    get "/t/#{topic.slug}/#{topic.id}/21"
    expect(response.headers["X-Robots-Tag"]).to eq("noindex")
    get "/t/#{topic.slug}/#{topic.id}?page=2"
    expect(response.headers["X-Robots-Tag"]).to be_nil
  end

  context "with default locale" do
    before do
      SiteSetting.default_locale = :fr
      sign_in(Fabricate(:user))
    end

    after { I18n.reload! }

    context "with rate limits" do
      before { RateLimiter.enable }

      it "serves a LimitExceeded error in the preferred locale" do
        SiteSetting.max_likes_per_day = 1
        post1 = Fabricate(:post)
        post2 = Fabricate(:post)
        override =
          TranslationOverride.create(
            locale: "fr",
            translation_key: "rate_limiter.by_type.create_like",
            value: "French LimitExceeded error message",
          )
        I18n.reload!

        post "/post_actions.json",
             params: {
               id: post1.id,
               post_action_type_id: PostActionType.types[:like],
             }
        expect(response.status).to eq(200)

        post "/post_actions.json",
             params: {
               id: post2.id,
               post_action_type_id: PostActionType.types[:like],
             }
        expect(response.status).to eq(429)
        expect(response.parsed_body["errors"].first).to eq(override.value)
      end
    end

    it "serves an InvalidParameters error with the default locale" do
      override =
        TranslationOverride.create(
          locale: "fr",
          translation_key: "invalid_params",
          value: "French InvalidParameters error message",
        )
      I18n.reload!

      get "/search.json", params: { q: "hello\0hello" }
      expect(response.status).to eq(400)
      expect(response.parsed_body["errors"].first).to eq(override.value)
    end
  end

  describe "set_locale" do
    # Using /bootstrap.json because it returns a locale-dependent value
    def headers(locale)
      { HTTP_ACCEPT_LANGUAGE: locale }
    end

    def locale_scripts(body)
      Nokogiri::HTML5
        .parse(body)
        .css('script[src*="assets/locales/"]')
        .map { |script| script.attributes["src"].value }
    end

    context "with allow_user_locale disabled" do
      context "when accept-language header differs from default locale" do
        before do
          SiteSetting.allow_user_locale = false
          SiteSetting.default_locale = "en"
        end

        context "with an anonymous user" do
          it "uses the default locale" do
            get "/latest", headers: headers("fr")
            expect(response.status).to eq(200)
            expect(locale_scripts(response.body)).to contain_exactly("/assets/locales/en.js")
          end
        end

        context "with a logged in user" do
          it "it uses the default locale" do
            user = Fabricate(:user, locale: :fr)
            sign_in(user)

            get "/latest", headers: headers("fr")
            expect(response.status).to eq(200)
            expect(locale_scripts(response.body)).to contain_exactly("/assets/locales/en.js")
          end
        end
      end
    end

    context "with set_locale_from_accept_language_header enabled" do
      context "when accept-language header differs from default locale" do
        before do
          SiteSetting.allow_user_locale = true
          SiteSetting.set_locale_from_accept_language_header = true
          SiteSetting.default_locale = "en"
        end

        context "with an anonymous user" do
          it "uses the locale from the headers" do
            get "/latest", headers: headers("fr")
            expect(response.status).to eq(200)
            expect(locale_scripts(response.body)).to contain_exactly("/assets/locales/fr.js")
          end

          it "doesn't leak after requests" do
            get "/latest", headers: headers("fr")
            expect(response.status).to eq(200)
            expect(locale_scripts(response.body)).to contain_exactly("/assets/locales/fr.js")
            expect(I18n.locale.to_s).to eq(SiteSettings::DefaultsProvider::DEFAULT_LOCALE)
          end
        end

        context "with a logged in user" do
          let(:user) { Fabricate(:user, locale: :fr) }

          before { sign_in(user) }

          it "uses the user's preferred locale" do
            get "/latest", headers: headers("fr")
            expect(response.status).to eq(200)
            expect(locale_scripts(response.body)).to contain_exactly("/assets/locales/fr.js")
          end

          it "serves a 404 page in the preferred locale" do
            get "/missingroute", headers: headers("fr")
            expect(response.status).to eq(404)
            expected_title = I18n.t("page_not_found.title", locale: :fr)
            expect(response.body).to include(CGI.escapeHTML(expected_title))
          end

          it "serves a RenderEmpty page in the preferred locale" do
            get "/u/#{user.username}/preferences/interface"
            expect(response.status).to eq(200)
            expect(response.body).to have_tag("script", with: { src: "/assets/locales/fr.js" })
          end
        end
      end

      context "when the preferred locale includes a region" do
        it "returns the locale and region separated by an underscore" do
          SiteSetting.allow_user_locale = true
          SiteSetting.set_locale_from_accept_language_header = true
          SiteSetting.default_locale = "en"

          get "/latest", headers: headers("zh-CN")
          expect(response.status).to eq(200)
          expect(locale_scripts(response.body)).to contain_exactly("/assets/locales/zh_CN.js")
        end
      end

      context "when accept-language header is not set" do
        it "uses the site default locale" do
          SiteSetting.allow_user_locale = true
          SiteSetting.default_locale = "en"

          get "/latest", headers: headers("")
          expect(response.status).to eq(200)
          expect(locale_scripts(response.body)).to contain_exactly("/assets/locales/en.js")
        end
      end
    end

    context "with set_locale_from_cookie enabled" do
      context "when cookie locale differs from default locale" do
        before do
          SiteSetting.allow_user_locale = true
          SiteSetting.set_locale_from_cookie = true
          SiteSetting.default_locale = "en"
        end

        context "with an anonymous user" do
          it "uses the locale from the cookie" do
            get "/latest", headers: { Cookie: "locale=es" }
            expect(response.status).to eq(200)
            expect(locale_scripts(response.body)).to contain_exactly("/assets/locales/es.js")
            expect(I18n.locale.to_s).to eq(SiteSettings::DefaultsProvider::DEFAULT_LOCALE) # doesn't leak after requests
          end
        end

        context "when the preferred locale includes a region" do
          it "returns the locale and region separated by an underscore" do
            get "/latest", headers: { Cookie: "locale=zh-CN" }
            expect(response.status).to eq(200)
            expect(locale_scripts(response.body)).to contain_exactly("/assets/locales/zh_CN.js")
          end
        end
      end

      context "when locale cookie is not set" do
        it "uses the site default locale" do
          SiteSetting.allow_user_locale = true
          SiteSetting.default_locale = "en"

          get "/latest", headers: { Cookie: "" }
          expect(response.status).to eq(200)
          expect(locale_scripts(response.body)).to contain_exactly("/assets/locales/en.js")
        end
      end
    end
  end

  describe "vary header" do
    it "includes Vary:Accept on all requests where format is not explicit" do
      # Rails default behaviour - include Vary:Accept when Accept is supplied
      get "/latest", headers: { "Accept" => "application/json" }
      expect(response.status).to eq(200)
      expect(response.headers["Vary"]).to eq("Accept")

      # Discourse additional behaviour (see lib/vary_header.rb)
      # Include Vary:Accept even when Accept is not supplied
      get "/latest"
      expect(response.status).to eq(200)
      expect(response.headers["Vary"]).to eq("Accept")

      # Not needed, because the path 'format' parameter overrides the Accept header
      get "/latest.json"
      expect(response.status).to eq(200)
      expect(response.headers["Vary"]).to eq(nil)
    end
  end

  describe "Discourse-Rate-Limit-Error-Code header" do
    fab!(:admin)

    before { RateLimiter.enable }

    it "is included when API key is rate limited" do
      global_setting :max_admin_api_reqs_per_minute, 1
      api_key = ApiKey.create!(user_id: admin.id).key
      get "/latest.json", headers: { "Api-Key": api_key, "Api-Username": admin.username }
      expect(response.status).to eq(200)

      get "/latest.json", headers: { "Api-Key": api_key, "Api-Username": admin.username }
      expect(response.status).to eq(429)
      expect(response.headers["Discourse-Rate-Limit-Error-Code"]).to eq("admin_api_key_rate_limit")
    end

    it "is included when user API key is rate limited" do
      global_setting :max_user_api_reqs_per_minute, 1
      user_api_key = UserApiKey.create!(user_id: admin.id)
      user_api_key.scopes =
        UserApiKeyScope.all_scopes.keys.map do |name|
          UserApiKeyScope.create!(name: name, user_api_key_id: user_api_key.id)
        end
      user_api_key.save!

      get "/session/current.json", headers: { "User-Api-Key": user_api_key.key }
      expect(response.status).to eq(200)

      get "/session/current.json", headers: { "User-Api-Key": user_api_key.key }
      expect(response.status).to eq(429)
      expect(response.headers["Discourse-Rate-Limit-Error-Code"]).to eq(
        "user_api_key_limiter_60_secs",
      )

      global_setting :max_user_api_reqs_per_minute, 100
      global_setting :max_user_api_reqs_per_day, 1

      get "/session/current.json", headers: { "User-Api-Key": user_api_key.key }
      expect(response.status).to eq(429)
      expect(response.headers["Discourse-Rate-Limit-Error-Code"]).to eq(
        "user_api_key_limiter_1_day",
      )
    end
  end

  describe "crawlers in slow_down_crawler_user_agents site setting" do
    before do
      Fabricate(:admin) # to prevent redirect to the wizard
      RateLimiter.enable

      SiteSetting.slow_down_crawler_rate = 128
      SiteSetting.slow_down_crawler_user_agents = "badcrawler|problematiccrawler"
    end

    it "are rate limited" do
      now = Time.zone.now
      freeze_time now

      get "/", headers: { "HTTP_USER_AGENT" => "iam badcrawler" }
      expect(response.status).to eq(200)
      get "/", headers: { "HTTP_USER_AGENT" => "iam badcrawler" }
      expect(response.status).to eq(429)
      expect(response.headers["Retry-After"]).to eq("128")

      get "/", headers: { "HTTP_USER_AGENT" => "iam problematiccrawler" }
      expect(response.status).to eq(200)
      get "/", headers: { "HTTP_USER_AGENT" => "iam problematiccrawler" }
      expect(response.status).to eq(429)
      expect(response.headers["Retry-After"]).to eq("128")

      freeze_time now + 100.seconds
      get "/", headers: { "HTTP_USER_AGENT" => "iam badcrawler" }
      expect(response.status).to eq(429)
      expect(response.headers["Retry-After"]).to eq("28")

      get "/", headers: { "HTTP_USER_AGENT" => "iam problematiccrawler" }
      expect(response.status).to eq(429)
      expect(response.headers["Retry-After"]).to eq("28")

      freeze_time now + 150.seconds
      get "/", headers: { "HTTP_USER_AGENT" => "iam badcrawler" }
      expect(response.status).to eq(200)

      get "/", headers: { "HTTP_USER_AGENT" => "iam problematiccrawler" }
      expect(response.status).to eq(200)
    end

    context "with anonymous caching" do
      before do
        global_setting :anon_cache_store_threshold, 1
        Middleware::AnonymousCache.enable_anon_cache
      end

      it "don't bypass crawler rate limits" do
        get "/", headers: { "HTTP_USER_AGENT" => "iam badcrawler" }
        expect(response.status).to eq(200)

        get "/", headers: { "HTTP_USER_AGENT" => "iam badcrawler" }
        expect(response.status).to eq(429)
      end

      context "with XHR requests" do
        before { global_setting :anon_cache_store_threshold, 1 }

        def preloaded_data
          response_html = Nokogiri::HTML5.fragment(response.body)
          JSON.parse(response_html.css("#data-preloaded")[0]["data-preloaded"])
        end

        it "does not return the same preloaded data for XHR and non-XHR requests" do
          # Request is stored in cache
          get "/", headers: { "X-Requested-With" => "XMLHTTPrequest" }
          expect(response.status).to eq(200)
          expect(response.headers["X-Discourse-Cached"]).to eq("store")
          expect(preloaded_data).not_to have_key("site")

          # Request is served from cache
          get "/", headers: { "X-Requested-With" => "xmlhttprequest" }
          expect(response.status).to eq(200)
          expect(response.headers["X-Discourse-Cached"]).to eq("true")
          expect(preloaded_data).not_to have_key("site")

          # Request is not served from cache because of different headers, but is stored
          get "/"
          expect(response.status).to eq(200)
          expect(response.headers["X-Discourse-Cached"]).to eq("store")
          expect(preloaded_data).to have_key("site")

          # Request is served from cache
          get "/", headers: { "X-Requested-With" => "xmlhttprequest" }
          expect(response.status).to eq(200)
          expect(response.headers["X-Discourse-Cached"]).to eq("true")
          expect(preloaded_data).not_to have_key("site")
        end
      end
    end
  end

  describe "#banner_json" do
    let(:admin) { Fabricate(:admin) }
    let(:user) { Fabricate(:user) }
    fab!(:banner_topic)
    fab!(:p1) { Fabricate(:post, topic: banner_topic, raw: "A banner topic") }

    before do
      admin # to skip welcome wizard at home page `/`
    end

    context "with login_required" do
      before { SiteSetting.login_required = true }
      it "does not include banner info for anonymous users" do
        get "/login"

        expect(response.body).to have_tag("div#data-preloaded") do |element|
          json = JSON.parse(element.current_scope.attribute("data-preloaded").value)
          expect(json["banner"]).to eq("{}")
        end
      end

      it "includes banner info for logged-in users" do
        sign_in(user)
        get "/"

        expect(response.body).to have_tag("div#data-preloaded") do |element|
          json = JSON.parse(element.current_scope.attribute("data-preloaded").value)
          expect(JSON.parse(json["banner"])["html"]).to eq("<p>A banner topic</p>")
        end
      end
    end

    context "with login not required" do
      before { SiteSetting.login_required = false }
      it "does include banner info for anonymous users" do
        get "/login"

        expect(response.body).to have_tag("div#data-preloaded") do |element|
          json = JSON.parse(element.current_scope.attribute("data-preloaded").value)
          expect(JSON.parse(json["banner"])["html"]).to eq("<p>A banner topic</p>")
        end
      end
    end
  end

  describe "Early hint header" do
    before { global_setting :cdn_url, "https://cdn.example.com/something" }

    it "is not included by default" do
      get "/latest"
      expect(response.status).to eq(200)
      expect(response.headers["Link"]).to eq(nil)
    end

    context "when in preconnect mode" do
      before { global_setting :early_hint_header_mode, "preconnect" }

      it "includes the preconnect hint" do
        get "/latest"
        expect(response.status).to eq(200)
        expect(response.headers["Link"]).to include("<https://cdn.example.com>; rel=preconnect")
        expect(response.headers["Link"]).not_to include("rel=preload")
      end

      it "can use a different header" do
        global_setting :early_hint_header_name, "X-Discourse-Early-Hint"
        get "/latest"
        expect(response.status).to eq(200)
        expect(response.headers["X-Discourse-Early-Hint"]).to include(
          "<https://cdn.example.com>; rel=preconnect",
        )
        expect(response.headers["Link"]).to eq(nil)
      end

      it "is skipped for non-app URLs" do
        get "/latest.json"
        expect(response.status).to eq(200)
        expect(response.headers["Link"]).to eq(nil)
      end
    end

    context "when in preload mode" do
      before { global_setting :early_hint_header_mode, "preload" }

      it "includes the preload hint" do
        get "/latest"
        expect(response.status).to eq(200)
        expect(response.headers["Link"]).to include('.js>; rel="preload"')
        expect(response.headers["Link"]).to include('.css?__ws=test.localhost>; rel="preload"')
      end
    end
  end

  describe "preloading data" do
    def preloaded_json
      JSON.parse(
        Nokogiri::HTML5.fragment(response.body).css("div#data-preloaded").first["data-preloaded"],
      )
    end

    context "when user is anon" do
      it "preloads the relevant JSON data" do
        get "/latest"
        expect(response.status).to eq(200)
        expect(preloaded_json.keys).to match_array(
          [
            "site",
            "siteSettings",
            "customHTML",
            "banner",
            "customEmoji",
            "isReadOnly",
            "isStaffWritesOnly",
            "activatedThemes",
            "#{TopicList.new("latest", Fabricate(:anonymous), []).preload_key}",
          ],
        )
      end
    end

    context "when user is regular user" do
      fab!(:user)

      before { sign_in(user) }

      it "preloads the relevant JSON data" do
        get "/latest"
        expect(response.status).to eq(200)
        expect(preloaded_json.keys).to match_array(
          [
            "site",
            "siteSettings",
            "customHTML",
            "banner",
            "customEmoji",
            "isReadOnly",
            "isStaffWritesOnly",
            "activatedThemes",
            "#{TopicList.new("latest", Fabricate(:anonymous), []).preload_key}",
            "currentUser",
            "topicTrackingStates",
            "topicTrackingStateMeta",
          ],
        )
      end
    end

    context "when user is admin" do
      fab!(:user) { Fabricate(:admin) }

      before { sign_in(user) }

      it "preloads the relevant JSON data" do
        get "/latest"
        expect(response.status).to eq(200)
        expect(preloaded_json.keys).to match_array(
          [
            "site",
            "siteSettings",
            "customHTML",
            "banner",
            "customEmoji",
            "isReadOnly",
            "isStaffWritesOnly",
            "activatedThemes",
            "#{TopicList.new("latest", Fabricate(:anonymous), []).preload_key}",
            "currentUser",
            "topicTrackingStates",
            "topicTrackingStateMeta",
            "fontMap",
            "visiblePlugins",
          ],
        )
      end

      it "generates a fontMap" do
        get "/latest"
        expect(response.status).to eq(200)
        font_map = JSON.parse(preloaded_json["fontMap"])
        expect(font_map.keys).to match_array(
          DiscourseFonts.fonts.filter { |f| f[:variants].present? }.map { |f| f[:key] },
        )
      end

      it "has correctly loaded visiblePlugins" do
        get "/latest"
        expect(JSON.parse(preloaded_json["visiblePlugins"])).to eq([])
      end
    end

    describe "readonly serialization" do
      it "serializes regular readonly mode correctly" do
        Discourse.enable_readonly_mode(Discourse::USER_READONLY_MODE_KEY)

        get "/latest"
        expect(JSON.parse(preloaded_json["isReadOnly"])).to eq(true)
        expect(JSON.parse(preloaded_json["isStaffWritesOnly"])).to eq(false)
      ensure
        Discourse.disable_readonly_mode(Discourse::USER_READONLY_MODE_KEY)
      end

      it "serializes staff readonly mode correctly" do
        Discourse.enable_readonly_mode(Discourse::STAFF_WRITES_ONLY_MODE_KEY)

        get "/latest"
        expect(JSON.parse(preloaded_json["isReadOnly"])).to eq(true)
        expect(JSON.parse(preloaded_json["isStaffWritesOnly"])).to eq(true)
      ensure
        Discourse.disable_readonly_mode(Discourse::STAFF_WRITES_ONLY_MODE_KEY)
      end
    end
  end

  describe "#set_current_user_for_logs" do
    fab!(:admin)

    it "sets the X-Discourse-Route header to the controller name and action including namespace" do
      sign_in(admin)

      get "/admin/users/#{admin.id}.json"
      expect(response.status).to eq(200)
      expect(response.headers["X-Discourse-Route"]).to eq("admin::users/show")

      get "/u/#{admin.username}.json"
      expect(response.status).to eq(200)
      expect(response.headers["X-Discourse-Route"]).to eq("users/show")
    end
  end
end
