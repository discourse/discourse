# frozen_string_literal: true

RSpec.describe SecondFactor::Actions::DiscourseConnectProvider do
  fab!(:user)

  let(:sso_secret) { "mysecretmyprecious" }

  let!(:sso) do
    ::DiscourseConnectProvider.new.tap do |sso|
      sso.nonce = "mysecurenonce"
      sso.return_sso_url = "http://hobbit.shire.com/sso"
      sso.sso_secret = sso_secret
      sso.require_2fa = true
    end
  end

  before do
    SiteSetting.enable_discourse_connect_provider = true
    SiteSetting.discourse_connect_provider_secrets = "hobbit.shire.com|#{sso_secret}"
  end

  def create_request(query_string)
    ActionDispatch::TestRequest.create(
      { "REQUEST_METHOD" => "GET", "PATH_INFO" => "/", "QUERY_STRING" => query_string },
    )
  end

  def params_from_payload(payload)
    ActionController::Parameters.new(Rack::Utils.parse_query(payload))
  end

  def create_instance(user, request = nil, opts = nil)
    request ||= create_request
    SecondFactor::Actions::DiscourseConnectProvider.new(
      Guardian.new(user),
      request,
      opts: opts,
      target_user: user,
    )
  end

  describe "#skip_second_factor_auth?" do
    it "returns true if there's no current_user" do
      request = create_request(sso.payload)
      params = params_from_payload(sso.payload)
      action = create_instance(nil, request)
      expect(action.skip_second_factor_auth?(params)).to eq(true)
    end

    it "returns true if SSO is for logout" do
      sso.logout = true
      request = create_request(sso.payload)
      params = params_from_payload(sso.payload)
      action = create_instance(user, request)
      expect(action.skip_second_factor_auth?(params)).to eq(true)
    end

    it "returns true if SSO doesn't require 2fa" do
      sso.require_2fa = false
      request = create_request(sso.payload)
      params = params_from_payload(sso.payload)
      action = create_instance(user, request)
      expect(action.skip_second_factor_auth?(params)).to eq(true)
    end

    it "returns true if 2fa has been confirmed during login" do
      request = create_request(sso.payload)
      params = params_from_payload(sso.payload)
      action = create_instance(user, request, confirmed_2fa_during_login: true)
      expect(action.skip_second_factor_auth?(params)).to eq(true)
    end

    it "returns falsey value otherwise" do
      request = create_request(sso.payload)
      params = params_from_payload(sso.payload)
      action = create_instance(user, request)
      expect(action.skip_second_factor_auth?(params)).to be_falsey
    end
  end

  describe "#second_factor_auth_skipped!" do
    before { sso.require_2fa = false }

    it "returns a hash with logout: true and return_sso_url without no payload if the SSO is for logout" do
      sso.logout = true
      request = create_request(sso.payload)
      params = params_from_payload(sso.payload)
      action = create_instance(user, request)
      expect(action.second_factor_auth_skipped!(params)).to eq(
        { logout: true, return_sso_url: "http://hobbit.shire.com/sso" },
      )
    end

    it "returns a hash with no_current_user: true if there's no current_user" do
      request = create_request(sso.payload)
      params = params_from_payload(sso.payload)
      action = create_instance(nil, request)
      expect(action.second_factor_auth_skipped!(params)).to eq({ no_current_user: true })
    end

    it "returns sso_redirect_url to the SSO website with payload that indicates confirmed 2FA if confirmed_2fa_during_login is true" do
      request = create_request(sso.payload)
      params = params_from_payload(sso.payload)
      action = create_instance(user, request, confirmed_2fa_during_login: true)
      output = action.second_factor_auth_skipped!(params)
      expect(output.keys).to contain_exactly(:sso_redirect_url)
      expect(output[:sso_redirect_url]).to start_with("http://hobbit.shire.com/sso")
      response_payload = ::DiscourseConnectProvider.parse(URI(output[:sso_redirect_url]).query)
      expect(response_payload.confirmed_2fa).to eq(true)
      expect(response_payload.no_2fa_methods).to eq(nil)
      expect(response_payload.username).to eq(user.username)
      expect(response_payload.email).to eq(user.email)
    end

    it "returns sso_redirect_url to the SSO website with payload that doesn't indicate confirmed 2FA" do
      request = create_request(sso.payload)
      params = params_from_payload(sso.payload)
      action = create_instance(user, request)
      output = action.second_factor_auth_skipped!(params)
      expect(output.keys).to contain_exactly(:sso_redirect_url)
      expect(output[:sso_redirect_url]).to start_with("http://hobbit.shire.com/sso")
      response_payload = ::DiscourseConnectProvider.parse(URI(output[:sso_redirect_url]).query)
      expect(response_payload.confirmed_2fa).to eq(nil)
      expect(response_payload.no_2fa_methods).to eq(nil)
      expect(response_payload.username).to eq(user.username)
      expect(response_payload.email).to eq(user.email)
    end

    it "prioritizes the SSO logout case over the no current_user case" do
      sso.logout = true
      request = create_request(sso.payload)
      params = params_from_payload(sso.payload)
      action = create_instance(nil, request)
      expect(action.second_factor_auth_skipped!(params)).to eq(
        { logout: true, return_sso_url: "http://hobbit.shire.com/sso" },
      )
    end
  end

  describe "#no_second_factors_enabled!" do
    let(:output) do
      request = create_request(sso.payload)
      params = params_from_payload(sso.payload)
      action = create_instance(user, request)
      action.no_second_factors_enabled!(params)
    end

    let(:response_payload) do
      ::DiscourseConnectProvider.parse(URI(output[:sso_redirect_url]).query)
    end

    it "returns a hash with just sso_redirect_url" do
      expect(output.keys).to contain_exactly(:sso_redirect_url)
    end

    it "the sso_redirect_url is the SSO site" do
      expect(output[:sso_redirect_url]).to start_with("http://hobbit.shire.com/sso")
    end

    it "the response payload indicates the user has no 2fa methods" do
      expect(response_payload.no_2fa_methods).to eq(true)
    end

    it "the response payload of the sso_redirect_url doesn't indicate the user has confirmed 2fa" do
      expect(response_payload.confirmed_2fa).to eq(nil)
    end

    it "the response payload contains the user details" do
      expect(response_payload.username).to eq(user.username)
      expect(response_payload.email).to eq(user.email)
    end
  end

  describe "#second_factor_auth_required!" do
    let(:output) do
      request = create_request(sso.payload)
      params = params_from_payload(sso.payload)
      action = create_instance(user, request)
      action.second_factor_auth_required!(params)
    end

    it "includes the payload in the callback_params" do
      expect(output[:callback_params]).to eq({ payload: sso.payload })
    end

    it "sets the callback_path to the SSO provider endpoint" do
      expect(output[:callback_path]).to eq("/session/sso_provider")
    end

    it "sets the callback_method to the HTTP method of SSO provider endpoint" do
      expect(output[:callback_method]).to eq("GET")
    end

    it "includes a description" do
      expect(output[:description]).to eq(
        I18n.t(
          "second_factor_auth.actions.discourse_connect_provider.description",
          hostname: "hobbit.shire.com",
        ),
      )
    end
  end

  describe "#second_factor_auth_completed!" do
    let(:output) do
      request = create_request("")
      action = create_instance(user, request)
      action.second_factor_auth_completed!(payload: sso.payload)
    end

    let(:response_payload) do
      ::DiscourseConnectProvider.parse(URI(output[:sso_redirect_url]).query)
    end

    it "gets the payload from callback_params and not the request params" do
      wrong_sso = ::DiscourseConnectProvider.new
      wrong_sso.nonce = "mysecurenonceWRONG"
      wrong_sso.return_sso_url = "http://wrong.shire.com/sso"
      wrong_sso.sso_secret = "mysecretmypreciousWRONG"
      wrong_sso.require_2fa = true

      request = create_request(wrong_sso.payload)
      action = create_instance(user, request)
      redirect_url = action.second_factor_auth_completed!(payload: sso.payload)[:sso_redirect_url]
      response_payload = ::DiscourseConnectProvider.parse(URI(redirect_url).query)
      expect(response_payload.return_sso_url).to eq("http://hobbit.shire.com/sso")
      expect(response_payload.nonce).to eq("mysecurenonce")
      expect(response_payload.sso_secret).to eq(sso_secret)
    end

    it "the response payload of the sso_redirect_url indicates the user has confirmed 2fa" do
      expect(response_payload.confirmed_2fa).to eq(true)
    end

    it "the response payload of the sso_redirect_url doesn't include no_2fa_methods" do
      expect(response_payload.no_2fa_methods).to eq(nil)
    end

    it "the response payload contains the user details" do
      user.update!(uploaded_avatar: Fabricate(:upload))
      user.user_profile.update!(
        profile_background_upload: Fabricate(:upload),
        card_background_upload: Fabricate(:upload),
      )

      expect(response_payload.name).to eq(user.name)
      expect(response_payload.username).to eq(user.username)
      expect(response_payload.email).to eq(user.email)
      expect(response_payload.external_id).to eq(user.id.to_s)
      expect(response_payload.admin).to eq(user.admin?)
      expect(response_payload.moderator).to eq(user.moderator?)
      expect(response_payload.groups).to eq(user.groups.pluck(:name).join(","))
      expect(response_payload.avatar_url).to eq(GlobalPath.full_cdn_url(user.uploaded_avatar.url))
      expect(response_payload.profile_background_url).to eq(
        GlobalPath.full_cdn_url(user.user_profile.profile_background_upload.url),
      )
      expect(response_payload.card_background_url).to eq(
        GlobalPath.full_cdn_url(user.user_profile.card_background_upload.url),
      )
    end
  end
end
