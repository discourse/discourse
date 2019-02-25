require 'rails_helper'

RSpec.describe SessionController do
  let(:email_token) { Fabricate(:email_token) }
  let(:user) { email_token.user }
  let(:logo_fixture) { "http://#{Discourse.current_hostname}/uploads/logo.png" }

  shared_examples 'failed to continue local login' do
    it 'should return the right response' do
      expect(response).not_to be_successful
      expect(response.status).to eq(500)
    end
  end

  describe '#email_login' do
    before do
      SiteSetting.enable_local_logins_via_email = true
    end

    context 'missing token' do
      it 'returns the right response' do
        get "/session/email-login"
        expect(response.status).to eq(404)
      end
    end

    context 'invalid token' do
      it 'returns the right response' do
        get "/session/email-login/adasdad"

        expect(response.status).to eq(200)

        expect(CGI.unescapeHTML(response.body)).to match(
          I18n.t('email_login.invalid_token')
        )
      end

      context 'when token has expired' do
        it 'should return the right response' do
          email_token.update!(created_at: 999.years.ago)

          get "/session/email-login/#{email_token.token}"

          expect(response.status).to eq(200)

          expect(CGI.unescapeHTML(response.body)).to match(
            I18n.t('email_login.invalid_token')
          )
        end
      end
    end

    context 'valid token' do
      it 'returns success' do
        get "/session/email-login/#{email_token.token}"

        expect(response).to redirect_to("/")
      end

      it 'fails when local logins via email is disabled' do
        SiteSetting.enable_local_logins_via_email = false

        get "/session/email-login/#{email_token.token}"

        expect(response.status).to eq(404)
      end

      it 'fails when local logins is disabled' do
        SiteSetting.enable_local_logins = false

        get "/session/email-login/#{email_token.token}"

        expect(response.status).to eq(500)
      end

      it "doesn't log in the user when not approved" do
        SiteSetting.must_approve_users = true

        get "/session/email-login/#{email_token.token}"

        expect(response.status).to eq(200)

        expect(CGI.unescapeHTML(response.body)).to include(
          I18n.t("login.not_approved")
        )
      end

      context "when admin IP address is not valid" do
        before do
          Fabricate(:screened_ip_address,
            ip_address: "111.111.11.11",
            action_type: ScreenedIpAddress.actions[:allow_admin]
          )

          SiteSetting.use_admin_ip_whitelist = true
          user.update!(admin: true)
        end

        it 'returns the right response' do
          get "/session/email-login/#{email_token.token}"

          expect(response.status).to eq(200)

          expect(CGI.unescapeHTML(response.body)).to include(
            I18n.t("login.admin_not_allowed_from_ip_address", username: user.username)
          )
        end
      end

      context "when IP address is blocked" do
        let(:permitted_ip_address) { '111.234.23.11' }

        before do
          Fabricate(:screened_ip_address,
            ip_address: permitted_ip_address,
            action_type: ScreenedIpAddress.actions[:block]
          )
        end

        it 'returns the right response' do
          ActionDispatch::Request.any_instance.stubs(:remote_ip).returns(permitted_ip_address)

          get "/session/email-login/#{email_token.token}"

          expect(response.status).to eq(200)

          expect(CGI.unescapeHTML(response.body)).to include(
            I18n.t("login.not_allowed_from_ip_address", username: user.username)
          )
        end
      end

      it "fails when user is suspended" do
        user.update!(
          suspended_till: 2.days.from_now,
          suspended_at: Time.zone.now
        )

        get "/session/email-login/#{email_token.token}"

        expect(response.status).to eq(200)

        expect(CGI.unescapeHTML(response.body)).to include(I18n.t("login.suspended",
          date: I18n.l(user.suspended_till, format: :date_only)
        ))
      end

      context 'user has 2-factor logins' do
        let!(:user_second_factor) { Fabricate(:user_second_factor_totp, user: user) }
        let!(:user_second_factor_backup) { Fabricate(:user_second_factor_backup, user: user) }

        describe 'requires second factor' do
          it 'should return a second factor prompt' do
            get "/session/email-login/#{email_token.token}"

            expect(response.status).to eq(200)

            response_body = CGI.unescapeHTML(response.body)

            expect(response_body).to include(I18n.t(
              "login.second_factor_title"
            ))

            expect(response_body).to_not include(I18n.t(
              "login.invalid_second_factor_code"
            ))
          end
        end

        describe 'errors on incorrect 2-factor' do
          context 'when using totp method' do
            it 'does not log in with incorrect two factor' do
              post "/session/email-login/#{email_token.token}", params: {
                second_factor_token: "0000",
                second_factor_method: UserSecondFactor.methods[:totp]
              }

              expect(response.status).to eq(200)

              expect(CGI.unescapeHTML(response.body)).to include(I18n.t(
                "login.invalid_second_factor_code"
              ))
            end
          end
          context 'when using backup code method' do
            it 'does not log in with incorrect backup code' do
              post "/session/email-login/#{email_token.token}", params: {
                second_factor_token: "0000",
                second_factor_method: UserSecondFactor.methods[:backup_codes]
              }

              expect(response.status).to eq(200)
              expect(CGI.unescapeHTML(response.body)).to include(I18n.t(
                "login.invalid_second_factor_code"
              ))
            end
          end
        end

        describe 'allows successful 2-factor' do
          context 'when using totp method' do
            it 'logs in correctly' do
              post "/session/email-login/#{email_token.token}", params: {
                second_factor_token: ROTP::TOTP.new(user_second_factor.data).now,
                second_factor_method: UserSecondFactor.methods[:totp]
              }

              expect(response).to redirect_to("/")
            end
          end
          context 'when using backup code method' do
            it 'logs in correctly' do
              post "/session/email-login/#{email_token.token}", params: {
                second_factor_token: "iAmValidBackupCode",
                second_factor_method: UserSecondFactor.methods[:backup_codes]
              }

              expect(response).to redirect_to("/")
            end
          end
        end
      end
    end
  end

  context 'logoff support' do
    it 'can log off users cleanly' do
      user = Fabricate(:user)
      sign_in(user)

      UserAuthToken.destroy_all

      # we need a route that will call current user
      post '/draft.json', params: {}
      expect(response.headers['Discourse-Logged-Out']).to eq("1")
    end
  end

  describe '#become' do
    let!(:user) { Fabricate(:user) }

    it "does not work when in production mode" do
      Rails.env.stubs(:production?).returns(true)
      get "/session/#{user.username}/become.json"

      expect(response.status).to eq(403)
      expect(JSON.parse(response.body)["error_type"]).to eq("invalid_access")
      expect(session[:current_user_id]).to be_blank
    end

    it "works in developmenet mode" do
      Rails.env.stubs(:development?).returns(true)
      get "/session/#{user.username}/become.json"
      expect(response).to be_redirect
      expect(session[:current_user_id]).to eq(user.id)
    end
  end

  describe '#sso_login' do
    before do
      @sso_url = "http://example.com/discourse_sso"
      @sso_secret = "shjkfdhsfkjh"

      SiteSetting.sso_url = @sso_url
      SiteSetting.enable_sso = true
      SiteSetting.sso_secret = @sso_secret

      # We have 2 options, either fabricate an admin or don't
      # send welcome messages
      Fabricate(:admin)
      # skip for now
      # SiteSetting.send_welcome_message = false
    end

    let(:headers) { { host: Discourse.current_hostname } }

    def get_sso(return_path)
      nonce = SecureRandom.hex
      dso = DiscourseSingleSignOn.new
      dso.nonce = nonce
      dso.register_nonce(return_path)

      sso = SingleSignOn.new
      sso.nonce = nonce
      sso.sso_secret = @sso_secret
      sso
    end

    it 'does not create superflous auth tokens when already logged in' do
      user = Fabricate(:user)
      sign_in(user)

      sso = get_sso("/")
      sso.email = user.email
      sso.external_id = 'abc'
      sso.username = 'sam'

      expect do
        get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
        logged_on_user = Discourse.current_user_provider.new(request.env).current_user
        expect(logged_on_user.id).to eq(user.id)
      end.not_to change { UserAuthToken.count }

    end

    it 'will never redirect back to /session/sso path' do
      sso = get_sso("/session/sso?bla=1")
      sso.email = user.email
      sso.external_id = 'abc'
      sso.username = 'sam'

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      expect(response).to redirect_to('/')

      sso = get_sso("http://#{Discourse.current_hostname}/session/sso?bla=1")
      sso.email = user.email
      sso.external_id = 'abc'
      sso.username = 'sam'

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      expect(response).to redirect_to('/')

    end

    it 'can take over an account' do
      sso = get_sso("/")
      user = Fabricate(:user)
      sso.email = user.email
      sso.external_id = 'abc'
      sso.username = 'sam'

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

      expect(response).to redirect_to('/')
      logged_on_user = Discourse.current_user_provider.new(request.env).current_user
      expect(logged_on_user.email).to eq(user.email)
      expect(logged_on_user.single_sign_on_record.external_id).to eq("abc")
      expect(logged_on_user.single_sign_on_record.external_username).to eq('sam')
    end

    def sso_for_ip_specs
      sso = get_sso('/a/')
      sso.external_id = '666' # the number of the beast
      sso.email = 'bob@bob.com'
      sso.name = 'Sam Saffron'
      sso.username = 'sam'
      sso
    end

    it 'respects IP restrictions on create' do
      ScreenedIpAddress.all.destroy_all
      get "/"
      screened_ip = Fabricate(:screened_ip_address, ip_address: request.remote_ip, action_type: ScreenedIpAddress.actions[:block])

      sso = sso_for_ip_specs
      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

      logged_on_user = Discourse.current_user_provider.new(request.env).current_user
      expect(logged_on_user).to eq(nil)
    end

    it 'respects IP restrictions on login' do
      ScreenedIpAddress.all.destroy_all
      get "/"
      sso = sso_for_ip_specs
      DiscourseSingleSignOn.parse(sso.payload).lookup_or_create_user(request.remote_ip)

      sso = sso_for_ip_specs
      screened_ip = Fabricate(:screened_ip_address, ip_address: request.remote_ip, action_type: ScreenedIpAddress.actions[:block])

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      logged_on_user = Discourse.current_user_provider.new(request.env).current_user
      expect(logged_on_user).to be_blank
    end

    it 'respects email restrictions' do
      sso = get_sso('/a/')
      sso.external_id = '666' # the number of the beast
      sso.email = 'bob@bob.com'
      sso.name = 'Sam Saffron'
      sso.username = 'sam'

      ScreenedEmail.block('bob@bob.com')
      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

      logged_on_user = Discourse.current_user_provider.new(request.env).current_user
      expect(logged_on_user).to eq(nil)
    end

    it 'allows you to create an admin account' do
      sso = get_sso('/a/')
      sso.external_id = '666' # the number of the beast
      sso.email = 'bob@bob.com'
      sso.name = 'Sam Saffron'
      sso.username = 'sam'
      sso.custom_fields["shop_url"] = "http://my_shop.com"
      sso.custom_fields["shop_name"] = "Sam"
      sso.admin = true

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

      logged_on_user = Discourse.current_user_provider.new(request.env).current_user
      expect(logged_on_user.admin).to eq(true)
    end

    it 'redirects to a non-relative url' do
      sso = get_sso("#{Discourse.base_url}/b/")
      sso.external_id = '666' # the number of the beast
      sso.email = 'bob@bob.com'
      sso.name = 'Sam Saffron'
      sso.username = 'sam'

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      expect(response).to redirect_to('/b/')
    end

    it 'redirects to random url if it is allowed' do
      SiteSetting.sso_allows_all_return_paths = true

      sso = get_sso('https://gusundtrout.com')
      sso.external_id = '666' # the number of the beast
      sso.email = 'bob@bob.com'
      sso.name = 'Sam Saffron'
      sso.username = 'sam'

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      expect(response).to redirect_to('https://gusundtrout.com')
    end

    it 'redirects to root if the host of the return_path is different' do
      sso = get_sso('//eviltrout.com')
      sso.external_id = '666' # the number of the beast
      sso.email = 'bob@bob.com'
      sso.name = 'Sam Saffron'
      sso.username = 'sam'

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      expect(response).to redirect_to('/')
    end

    it 'redirects to root if the host of the return_path is different' do
      sso = get_sso('http://eviltrout.com')
      sso.external_id = '666' # the number of the beast
      sso.email = 'bob@bob.com'
      sso.name = 'Sam Saffron'
      sso.username = 'sam'

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      expect(response).to redirect_to('/')
    end

    it 'allows you to create an account' do
      sso = get_sso('/a/')
      sso.external_id = '666' # the number of the beast
      sso.email = 'bob@bob.com'
      sso.name = 'Sam Saffron'
      sso.username = 'sam'
      sso.custom_fields["shop_url"] = "http://my_shop.com"
      sso.custom_fields["shop_name"] = "Sam"

      events = DiscourseEvent.track_events do
        get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      end

      expect(events.map { |event| event[:event_name] }).to include(
       :user_logged_in, :user_first_logged_in
      )

      expect(response).to redirect_to('/a/')

      logged_on_user = Discourse.current_user_provider.new(request.env).current_user

      # ensure nothing is transient
      logged_on_user = User.find(logged_on_user.id)

      expect(logged_on_user.admin).to eq(false)
      expect(logged_on_user.email).to eq('bob@bob.com')
      expect(logged_on_user.name).to eq('Sam Saffron')
      expect(logged_on_user.username).to eq('sam')

      expect(logged_on_user.single_sign_on_record.external_id).to eq("666")
      expect(logged_on_user.single_sign_on_record.external_username).to eq('sam')
      expect(logged_on_user.active).to eq(true)
      expect(logged_on_user.custom_fields["shop_url"]).to eq("http://my_shop.com")
      expect(logged_on_user.custom_fields["shop_name"]).to eq("Sam")
      expect(logged_on_user.custom_fields["bla"]).to eq(nil)
    end

    context 'when sso emails are not trusted' do
      context 'if you have not activated your account' do
        it 'does not log you in' do
          sso = get_sso('/a/')
          sso.external_id = '666' # the number of the beast
          sso.email = 'bob@bob.com'
          sso.name = 'Sam Saffron'
          sso.username = 'sam'
          sso.require_activation = true

          get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

          logged_on_user = Discourse.current_user_provider.new(request.env).current_user
          expect(logged_on_user).to eq(nil)
        end

        it 'sends an activation email' do
          sso = get_sso('/a/')
          sso.external_id = '666' # the number of the beast
          sso.email = 'bob@bob.com'
          sso.name = 'Sam Saffron'
          sso.username = 'sam'
          sso.require_activation = true

          get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
          expect(Jobs::CriticalUserEmail.jobs.size).to eq(1)
        end
      end

      context 'if you have activated your account' do
        it 'allows you to log in' do
          sso = get_sso('/hello/world')
          sso.external_id = '997'
          sso.sso_url = "http://somewhere.over.com/sso_login"
          sso.require_activation = true

          user = Fabricate(:user)
          user.create_single_sign_on_record(external_id: '997', last_payload: '')
          user.stubs(:active?).returns(true)

          get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

          logged_on_user = Discourse.current_user_provider.new(request.env).current_user
          expect(user.id).to eq(logged_on_user.id)
        end
      end
    end

    it 'allows login to existing account with valid nonce' do
      sso = get_sso('/hello/world')
      sso.external_id = '997'
      sso.sso_url = "http://somewhere.over.com/sso_login"

      user = Fabricate(:user)
      user.create_single_sign_on_record(external_id: '997', last_payload: '')

      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

      user.single_sign_on_record.reload
      expect(user.single_sign_on_record.last_payload).to eq(sso.unsigned_payload)

      expect(response).to redirect_to('/hello/world')
      logged_on_user = Discourse.current_user_provider.new(request.env).current_user

      expect(user.id).to eq(logged_on_user.id)

      # nonce is bad now
      get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers
      expect(response.status).to eq(419)
    end

    context "when sso provider is enabled" do
      before do
        SiteSetting.enable_sso_provider = true
        SiteSetting.sso_provider_secrets = [
          "*|secret,forAll",
          "*.rainbow|wrongSecretForOverRainbow",
          "www.random.site|secretForRandomSite",
          "somewhere.over.rainbow|secretForOverRainbow",
        ].join("\n")
      end

      it "doesn't break" do
        sso = get_sso('/hello/world')
        sso.external_id = '997'
        sso.sso_url = "http://somewhere.over.com/sso_login"
        sso.return_sso_url = "http://someurl.com"

        user = Fabricate(:user)
        user.create_single_sign_on_record(external_id: '997', last_payload: '')

        get "/session/sso_login", params: Rack::Utils.parse_query(sso.payload), headers: headers

        user.single_sign_on_record.reload
        expect(user.single_sign_on_record.last_payload).to eq(sso.unsigned_payload)

        expect(response).to redirect_to('/hello/world')
        logged_on_user = Discourse.current_user_provider.new(request.env).current_user

        expect(user.id).to eq(logged_on_user.id)
      end
    end

    it 'returns the correct error code for invalid signature' do
      sso = get_sso('/hello/world')
      sso.external_id = '997'
      sso.sso_url = "http://somewhere.over.com/sso_login"

      correct_params = Rack::Utils.parse_query(sso.payload)
      get "/session/sso_login", params: correct_params.merge("sig": "thisisnotthesigyouarelookingfor"), headers: headers
      expect(response.status).to eq(422)
      expect(response.body).not_to include(correct_params["sig"]) # Check we didn't send the real sig back to the client
      logged_on_user = Discourse.current_user_provider.new(request.env).current_user
      expect(logged_on_user).to eq(nil)

      correct_params = Rack::Utils.parse_query(sso.payload)
      get "/session/sso_login", params: correct_params.merge("sig": "thisisasignaturewith@special!characters"), headers: headers
      expect(response.status).to eq(422)
      expect(response.body).not_to include(correct_params["sig"]) # Check we didn't send the real sig back to the client
      logged_on_user = Discourse.current_user_provider.new(request.env).current_user
      expect(logged_on_user).to eq(nil)
    end

    describe 'local attribute override from SSO payload' do
      before do
        SiteSetting.email_editable = false
        SiteSetting.sso_overrides_email = true
        SiteSetting.sso_overrides_username = true
        SiteSetting.sso_overrides_name = true

        @user = Fabricate(:user)

        @sso = get_sso('/hello/world')
        @sso.external_id = '997'

        @reversed_username = @user.username.reverse
        @sso.username = @reversed_username
        @sso.email = "#{@reversed_username}@garbage.org"
        @reversed_name = @user.name.reverse
        @sso.name = @reversed_name

        @suggested_username = UserNameSuggester.suggest(@sso.username || @sso.name || @sso.email)
        @suggested_name = User.suggest_name(@sso.name || @sso.username || @sso.email)
        @user.create_single_sign_on_record(external_id: '997', last_payload: '')
      end

      it 'stores the external attributes' do
        get "/session/sso_login", params: Rack::Utils.parse_query(@sso.payload), headers: headers
        @user.single_sign_on_record.reload
        expect(@user.single_sign_on_record.external_username).to eq(@sso.username)
        expect(@user.single_sign_on_record.external_email).to eq(@sso.email)
        expect(@user.single_sign_on_record.external_name).to eq(@sso.name)
      end

      it 'overrides attributes' do
        get "/session/sso_login", params: Rack::Utils.parse_query(@sso.payload), headers: headers

        logged_on_user = Discourse.current_user_provider.new(request.env).current_user
        expect(logged_on_user.username).to eq(@suggested_username)
        expect(logged_on_user.email).to eq("#{@reversed_username}@garbage.org")
        expect(logged_on_user.name).to eq(@sso.name)
      end

      it 'does not change matching attributes for an existing account' do
        @sso.username = @user.username
        @sso.name = @user.name
        @sso.email = @user.email

        get "/session/sso_login", params: Rack::Utils.parse_query(@sso.payload), headers: headers

        logged_on_user = Discourse.current_user_provider.new(request.env).current_user
        expect(logged_on_user.username).to eq(@user.username)
        expect(logged_on_user.name).to eq(@user.name)
        expect(logged_on_user.email).to eq(@user.email)
      end
    end
  end

  describe '#sso_provider' do
    let(:headers) { { host: Discourse.current_hostname } }

    describe 'can act as an SSO provider' do
      before do
        stub_request(:any, /#{Discourse.current_hostname}\/uploads/).to_return(
          status: 200,
          body: lambda { |request| file_from_fixtures("logo.png") }
        )

        SiteSetting.enable_sso_provider = true
        SiteSetting.enable_sso = false
        SiteSetting.enable_local_logins = true
        SiteSetting.sso_provider_secrets = [
          "*|secret,forAll",
          "*.rainbow|wrongSecretForOverRainbow",
          "www.random.site|secretForRandomSite",
          "somewhere.over.rainbow|secretForOverRainbow",
        ].join("\n")

        @sso = SingleSignOnProvider.new
        @sso.nonce = "mynonce"
        @sso.return_sso_url = "http://somewhere.over.rainbow/sso"

        @user = Fabricate(:user, password: "myfrogs123ADMIN", active: true, admin: true)
        group = Fabricate(:group)
        group.add(@user)

        @user.create_user_avatar!
        UserAvatar.import_url_for_user(logo_fixture, @user)
        UserProfile.import_url_for_user(logo_fixture, @user, is_card_background: false)
        UserProfile.import_url_for_user(logo_fixture, @user, is_card_background: true)

        @user.reload
        @user.user_avatar.reload
        @user.user_profile.reload
        EmailToken.update_all(confirmed: true)
      end

      it "successfully logs in and redirects user to return_sso_url when the user is not logged in" do
        get "/session/sso_provider", params: Rack::Utils.parse_query(@sso.payload("secretForOverRainbow"))

        expect(response).to redirect_to("/login")

        post "/session.json",
          params: { login: @user.username, password: "myfrogs123ADMIN" }, xhr: true, headers: headers

        location = response.cookies["sso_destination_url"]
        # javascript code will handle redirection of user to return_sso_url
        expect(location).to match(/^http:\/\/somewhere.over.rainbow\/sso/)

        payload = location.split("?")[1]
        sso2 = SingleSignOnProvider.parse(payload)

        expect(sso2.email).to eq(@user.email)
        expect(sso2.name).to eq(@user.name)
        expect(sso2.username).to eq(@user.username)
        expect(sso2.external_id).to eq(@user.id.to_s)
        expect(sso2.admin).to eq(true)
        expect(sso2.moderator).to eq(false)
        expect(sso2.groups).to eq(@user.groups.pluck(:name).join(","))

        expect(sso2.avatar_url.blank?).to_not eq(true)
        expect(sso2.profile_background_url.blank?).to_not eq(true)
        expect(sso2.card_background_url.blank?).to_not eq(true)

        expect(sso2.avatar_url).to start_with(Discourse.base_url)
        expect(sso2.profile_background_url).to start_with(Discourse.base_url)
        expect(sso2.card_background_url).to start_with(Discourse.base_url)
      end

      it "it fails to log in if secret is wrong" do
        get "/session/sso_provider", params: Rack::Utils.parse_query(@sso.payload("secretForRandomSite"))

        expect(response.status).to eq(500)
      end

      it "successfully redirects user to return_sso_url when the user is logged in" do
        sign_in(@user)

        get "/session/sso_provider", params: Rack::Utils.parse_query(@sso.payload("secretForOverRainbow"))

        location = response.header["Location"]
        expect(location).to match(/^http:\/\/somewhere.over.rainbow\/sso/)

        payload = location.split("?")[1]
        sso2 = SingleSignOnProvider.parse(payload)

        expect(sso2.email).to eq(@user.email)
        expect(sso2.name).to eq(@user.name)
        expect(sso2.username).to eq(@user.username)
        expect(sso2.external_id).to eq(@user.id.to_s)
        expect(sso2.admin).to eq(true)
        expect(sso2.moderator).to eq(false)
        expect(sso2.groups).to eq(@user.groups.pluck(:name).join(","))

        expect(sso2.avatar_url.blank?).to_not eq(true)
        expect(sso2.profile_background_url.blank?).to_not eq(true)
        expect(sso2.card_background_url.blank?).to_not eq(true)

        expect(sso2.avatar_url).to start_with(Discourse.base_url)
        expect(sso2.profile_background_url).to start_with(Discourse.base_url)
        expect(sso2.card_background_url).to start_with(Discourse.base_url)
      end

      it 'handles non local content correctly' do
        SiteSetting.avatar_sizes = "100|49"
        SiteSetting.enable_s3_uploads = true
        SiteSetting.s3_access_key_id = "XXX"
        SiteSetting.s3_secret_access_key = "XXX"
        SiteSetting.s3_upload_bucket = "test"
        SiteSetting.s3_cdn_url = "http://cdn.com"

        stub_request(:any, /test.s3.dualstack.us-east-1.amazonaws.com/).to_return(status: 200, body: "", headers: { referer: "fgdfds" })

        @user.create_user_avatar!
        upload = Fabricate(:upload, url: "//test.s3.dualstack.us-east-1.amazonaws.com/something")

        Fabricate(:optimized_image,
          sha1: SecureRandom.hex << "A" * 8,
          upload: upload,
          width: 98,
          height: 98,
          url: "//test.s3.amazonaws.com/something/else"
        )

        @user.update_columns(uploaded_avatar_id: upload.id)
        @user.user_profile.update_columns(
          profile_background: "//test.s3.dualstack.us-east-1.amazonaws.com/something",
          card_background: "//test.s3.dualstack.us-east-1.amazonaws.com/something"
        )

        @user.reload
        @user.user_avatar.reload
        @user.user_profile.reload

        sign_in(@user)

        stub_request(:get, "http://cdn.com/something/else").to_return(
          body: lambda { |request| File.new(Rails.root + 'spec/fixtures/images/logo.png') }
        )

        get "/session/sso_provider", params: Rack::Utils.parse_query(@sso.payload("secretForOverRainbow"))

        location = response.header["Location"]
        # javascript code will handle redirection of user to return_sso_url
        expect(location).to match(/^http:\/\/somewhere.over.rainbow\/sso/)

        payload = location.split("?")[1]
        sso2 = SingleSignOnProvider.parse(payload)

        expect(sso2.avatar_url.blank?).to_not eq(true)
        expect(sso2.profile_background_url.blank?).to_not eq(true)
        expect(sso2.card_background_url.blank?).to_not eq(true)

        expect(sso2.avatar_url).to start_with("#{SiteSetting.s3_cdn_url}/original")
        expect(sso2.profile_background_url).to start_with(SiteSetting.s3_cdn_url)
        expect(sso2.card_background_url).to start_with(SiteSetting.s3_cdn_url)
      end
    end
  end

  describe '#create' do
    let(:user) { Fabricate(:user) }

    context 'local login is disabled' do
      before do
        SiteSetting.enable_local_logins = false

        post "/session.json", params: {
          login: user.username, password: 'myawesomepassword'
        }
      end
      it_behaves_like "failed to continue local login"
    end

    context 'SSO is enabled' do
      before do
        SiteSetting.sso_url = "https://www.example.com/sso"
        SiteSetting.enable_sso = true

        post "/session.json", params: {
          login: user.username, password: 'myawesomepassword'
        }
      end
      it_behaves_like "failed to continue local login"
    end

    context 'when email is confirmed' do
      before do
        token = user.email_tokens.find_by(email: user.email)
        EmailToken.confirm(token.token)
      end

      it "raises an error when the login isn't present" do
        post "/session.json"
        expect(response.status).to eq(400)
      end

      describe 'invalid password' do
        it "should return an error with an invalid password" do
          post "/session.json", params: {
            login: user.username, password: 'sssss'
          }

          expect(response.status).to eq(200)
          expect(::JSON.parse(response.body)['error']).to eq(
            I18n.t("login.incorrect_username_email_or_password")
          )
        end
      end

      describe 'invalid password' do
        it "should return an error with an invalid password if too long" do
          User.any_instance.expects(:confirm_password?).never
          post "/session.json", params: {
            login: user.username, password: ('s' * (User.max_password_length + 1))
          }

          expect(response.status).to eq(200)
          expect(::JSON.parse(response.body)['error']).to eq(
            I18n.t("login.incorrect_username_email_or_password")
          )
        end
      end

      describe 'suspended user' do
        it 'should return an error' do
          user.suspended_till = 2.days.from_now
          user.suspended_at = Time.now
          user.save!
          StaffActionLogger.new(user).log_user_suspend(user, "<strike>banned</strike>")

          post "/session.json", params: {
            login: user.username, password: 'myawesomepassword'
          }

          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)['error']).to eq(I18n.t('login.suspended_with_reason',
            date: I18n.l(user.suspended_till, format: :date_only),
            reason: Rack::Utils.escape_html(user.suspend_reason)
          ))
        end
      end

      describe 'deactivated user' do
        it 'should return an error' do
          user.active = false
          user.save!

          post "/session.json", params: {
            login: user.username, password: 'myawesomepassword'
          }

          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)['error']).to eq(I18n.t('login.not_activated'))
        end
      end

      describe 'success by username' do
        it 'logs in correctly' do
          events = DiscourseEvent.track_events do
            post "/session.json", params: {
              login: user.username, password: 'myawesomepassword'
            }
          end

          expect(response.status).to eq(200)
          expect(events.map { |event| event[:event_name] }).to contain_exactly(
            :user_logged_in, :user_first_logged_in
          )

          user.reload

          expect(session[:current_user_id]).to eq(user.id)
          expect(user.user_auth_tokens.count).to eq(1)
          expect(UserAuthToken.hash_token(cookies[:_t])).to eq(user.user_auth_tokens.first.auth_token)
        end
      end

      context 'when user has 2-factor logins' do
        let!(:user_second_factor) { Fabricate(:user_second_factor_totp, user: user) }
        let!(:user_second_factor_backup) { Fabricate(:user_second_factor_backup, user: user) }

        describe 'when second factor token is missing' do
          it 'should return the right response' do
            post "/session.json", params: {
              login: user.username,
              password: 'myawesomepassword',
            }

            expect(response.status).to eq(200)
            expect(JSON.parse(response.body)['error']).to eq(I18n.t(
              'login.invalid_second_factor_code'
            ))
          end
        end

        describe 'when second factor token is invalid' do
          context 'when using totp method' do
            it 'should return the right response' do
              post "/session.json", params: {
                login: user.username,
                password: 'myawesomepassword',
                second_factor_token: '00000000',
                second_factor_method: UserSecondFactor.methods[:totp]
              }

              expect(response.status).to eq(200)
              expect(JSON.parse(response.body)['error']).to eq(I18n.t(
                'login.invalid_second_factor_code'
              ))
            end
          end
          context 'when using backup code method' do
            it 'should return the right response' do
              post "/session.json", params: {
                login: user.username,
                password: 'myawesomepassword',
                second_factor_token: '00000000',
                second_factor_method: UserSecondFactor.methods[:backup_codes]
              }

              expect(response.status).to eq(200)
              expect(JSON.parse(response.body)['error']).to eq(I18n.t(
                'login.invalid_second_factor_code'
              ))
            end
          end
        end

        describe 'when second factor token is valid' do
          context 'when using totp method' do
            it 'should log the user in' do
              post "/session.json", params: {
                login: user.username,
                password: 'myawesomepassword',
                second_factor_token: ROTP::TOTP.new(user_second_factor.data).now,
                second_factor_method: UserSecondFactor.methods[:totp]
              }
              expect(response.status).to eq(200)
              user.reload

              expect(session[:current_user_id]).to eq(user.id)
              expect(user.user_auth_tokens.count).to eq(1)

              expect(UserAuthToken.hash_token(cookies[:_t]))
                .to eq(user.user_auth_tokens.first.auth_token)
            end
          end
          context 'when using backup code method' do
            it 'should log the user in' do
              post "/session.json", params: {
                login: user.username,
                password: 'myawesomepassword',
                second_factor_token: 'iAmValidBackupCode',
                second_factor_method: UserSecondFactor.methods[:backup_codes]
              }
              expect(response.status).to eq(200)
              user.reload

              expect(session[:current_user_id]).to eq(user.id)
              expect(user.user_auth_tokens.count).to eq(1)

              expect(UserAuthToken.hash_token(cookies[:_t]))
                .to eq(user.user_auth_tokens.first.auth_token)
            end
          end
        end
      end

      describe 'with a blocked IP' do
        it "doesn't log in" do
          ScreenedIpAddress.all.destroy_all
          get "/"
          screened_ip = Fabricate(:screened_ip_address, ip_address: request.remote_ip)
          post "/session.json", params: {
            login: "@" + user.username, password: 'myawesomepassword'
          }
          expect(response.status).to eq(200)
          user.reload

          expect(session[:current_user_id]).to be_nil
        end
      end

      describe 'strips leading @ symbol' do
        it 'sets a session id' do
          post "/session.json", params: {
            login: "@" + user.username, password: 'myawesomepassword'
          }
          expect(response.status).to eq(200)
          user.reload

          expect(session[:current_user_id]).to eq(user.id)
        end
      end

      describe 'also allow login by email' do
        it 'sets a session id' do
          post "/session.json", params: {
            login: user.email, password: 'myawesomepassword'
          }
          expect(response.status).to eq(200)
          expect(session[:current_user_id]).to eq(user.id)
        end
      end

      context 'login has leading and trailing space' do
        let(:username) { " #{user.username} " }
        let(:email) { " #{user.email} " }

        it "strips spaces from the username" do
          post "/session.json", params: {
            login: username, password: 'myawesomepassword'
          }
          expect(response.status).to eq(200)
          expect(::JSON.parse(response.body)['error']).not_to be_present
        end

        it "strips spaces from the email" do
          post "/session.json", params: {
            login: email, password: 'myawesomepassword'
          }
          expect(response.status).to eq(200)
          expect(::JSON.parse(response.body)['error']).not_to be_present
        end
      end

      describe "when the site requires approval of users" do
        before do
          SiteSetting.must_approve_users = true
        end

        context 'with an unapproved user' do
          before do
            post "/session.json", params: {
              login: user.email, password: 'myawesomepassword'
            }
          end

          it "doesn't log in the user" do
            expect(response.status).to eq(200)
            expect(session[:current_user_id]).to be_blank
          end

          it "shows the 'not approved' error message" do
            expect(response.status).to eq(200)
            expect(JSON.parse(response.body)['error']).to eq(
              I18n.t('login.not_approved')
            )
          end
        end

        context "with an unapproved user who is an admin" do
          it 'sets a session id' do
            user.admin = true
            user.save!

            post "/session.json", params: {
              login: user.email, password: 'myawesomepassword'
            }
            expect(response.status).to eq(200)
            expect(session[:current_user_id]).to eq(user.id)
          end
        end
      end

      context 'when admins are restricted by ip address' do
        let(:permitted_ip_address) { '111.234.23.11' }
        before do
          SiteSetting.use_admin_ip_whitelist = true
          ScreenedIpAddress.all.destroy_all
        end

        it 'is successful for admin at the ip address' do
          get "/"
          Fabricate(:screened_ip_address, ip_address: request.remote_ip, action_type: ScreenedIpAddress.actions[:allow_admin])

          user.admin = true
          user.save!

          post "/session.json", params: {
            login: user.username, password: 'myawesomepassword'
          }
          expect(response.status).to eq(200)
          expect(session[:current_user_id]).to eq(user.id)
        end

        it 'returns an error for admin not at the ip address' do
          Fabricate(:screened_ip_address, ip_address: "111.234.23.11", action_type: ScreenedIpAddress.actions[:allow_admin])
          user.admin = true
          user.save!

          post "/session.json", params: {
            login: user.username, password: 'myawesomepassword'
          }

          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)['error']).to be_present
          expect(session[:current_user_id]).not_to eq(user.id)
        end

        it 'is successful for non-admin not at the ip address' do
          Fabricate(:screened_ip_address, ip_address: "111.234.23.11", action_type: ScreenedIpAddress.actions[:allow_admin])
          user.admin = false
          user.save!

          post "/session.json", params: {
            login: user.username, password: 'myawesomepassword'
          }

          expect(response.status).to eq(200)
          expect(session[:current_user_id]).to eq(user.id)
        end
      end
    end

    context 'when email has not been confirmed' do
      def post_login
        post "/session.json", params: {
          login: user.email, password: 'myawesomepassword'
        }
      end

      it "doesn't log in the user" do
        post_login
        expect(response.status).to eq(200)
        expect(session[:current_user_id]).to be_blank
      end

      it "shows the 'not activated' error message" do
        post_login
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)['error']).to eq(
          I18n.t 'login.not_activated'
        )
      end

      context "and the 'must approve users' site setting is enabled" do
        before { SiteSetting.must_approve_users = true }

        it "shows the 'not approved' error message" do
          post_login
          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)['error']).to eq(
            I18n.t 'login.not_approved'
          )
        end
      end
    end

    context 'rate limited' do
      it 'rate limits login' do
        SiteSetting.max_logins_per_ip_per_hour = 2
        RateLimiter.enable
        RateLimiter.clear_all!

        2.times do
          post "/session.json", params: {
            login: user.username, password: 'myawesomepassword'
          }

          expect(response.status).to eq(200)
        end

        post "/session.json", params: {
          login: user.username, password: 'myawesomepassword'
        }

        expect(response.status).to eq(429)
        json = JSON.parse(response.body)
        expect(json["error_type"]).to eq("rate_limit")
      end

      it 'rate limits second factor attempts' do
        RateLimiter.enable
        RateLimiter.clear_all!

        3.times do
          post "/session.json", params: {
            login: user.username,
            password: 'myawesomepassword',
            second_factor_token: '000000'
          }

          expect(response.status).to eq(200)
        end

        post "/session.json", params: {
          login: user.username,
          password: 'myawesomepassword',
          second_factor_token: '000000'
        }

        expect(response.status).to eq(429)
        json = JSON.parse(response.body)
        expect(json["error_type"]).to eq("rate_limit")
      end
    end
  end

  describe '#destroy' do
    it 'removes the session variable and the auth token cookies' do
      user = sign_in(Fabricate(:user))
      delete "/session/#{user.username}.json"

      expect(response.status).to eq(302)
      expect(session[:current_user_id]).to be_blank
      expect(response.cookies["_t"]).to be_blank
    end
  end

  describe '#forgot_password' do
    it 'raises an error without a username parameter' do
      post "/session/forgot_password.json"
      expect(response.status).to eq(400)
    end

    context 'for a non existant username' do
      it "doesn't generate a new token for a made up username" do
        expect do
          post "/session/forgot_password.json", params: { login: 'made_up' }
        end.not_to change(EmailToken, :count)
        expect(Jobs::CriticalUserEmail.jobs.size).to eq(0)
      end
    end

    context 'for an existing username' do
      let(:user) { Fabricate(:user) }

      context 'local login is disabled' do
        before do
          SiteSetting.enable_local_logins = false
          post "/session/forgot_password.json", params: { login: user.username }
        end
        it_behaves_like "failed to continue local login"
      end

      context 'SSO is enabled' do
        before do
          SiteSetting.sso_url = "https://www.example.com/sso"
          SiteSetting.enable_sso = true

          post "/session.json", params: {
            login: user.username, password: 'myawesomepassword'
          }
        end
        it_behaves_like "failed to continue local login"
      end

      it "generates a new token for a made up username" do
        expect do
          post "/session/forgot_password.json", params: { login: user.username }
        end.to change(EmailToken, :count)
      end

      it "enqueues an email" do
        post "/session/forgot_password.json", params: { login: user.username }
        expect(Jobs::CriticalUserEmail.jobs.size).to eq(1)
      end
    end

    context 'do nothing to system username' do
      let(:system) { Discourse.system_user }

      it 'generates no token for system username' do
        expect do
          post "/session/forgot_password.json", params: { login: system.username }
        end.not_to change(EmailToken, :count)
      end

      it 'enqueues no email' do
        post "/session/forgot_password.json", params: { login: system.username }
        expect(Jobs::CriticalUserEmail.jobs.size).to eq(0)
      end
    end

    context 'for a staged account' do
      let!(:staged) { Fabricate(:staged) }

      it 'generates no token for staged username' do
        expect do
          post "/session/forgot_password.json", params: { login: staged.username }
        end.not_to change(EmailToken, :count)
      end

      it 'enqueues no email' do
        post "/session/forgot_password.json", params: { login: staged.username }
        expect(Jobs::CriticalUserEmail.jobs.size).to eq(0)
      end
    end
  end

  describe '#current' do
    context "when not logged in" do
      it "retuns 404" do
        get "/session/current.json"
        expect(response.status).to eq(404)
      end
    end

    context "when logged in" do
      let!(:user) { sign_in(Fabricate(:user)) }

      it "returns the JSON for the user" do
        get "/session/current.json"
        expect(response.status).to eq(200)
        json = ::JSON.parse(response.body)
        expect(json['current_user']).to be_present
        expect(json['current_user']['id']).to eq(user.id)
      end
    end
  end
end
