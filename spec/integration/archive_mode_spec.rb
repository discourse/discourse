# frozen_string_literal: true

RSpec.describe "Archive mode" do
  fab!(:user)
  fab!(:category)

  before { Discourse.enable_readonly_mode(Discourse::ARCHIVE_MODE_KEY) }

  after do
    Discourse.disable_readonly_mode(Discourse::ARCHIVE_MODE_KEY)
    Discourse.disable_readonly_mode(Discourse::USER_READONLY_MODE_KEY)
    Discourse.disable_readonly_mode(Discourse::STAFF_WRITES_ONLY_MODE_KEY)
  end

  it "reports the site as read-only" do
    expect(Discourse.readonly_mode?).to eq(true)
    expect(Discourse.archive_mode_active?).to eq(true)
  end

  it "preloads isArchived so the frontend can swap the banner" do
    get "/latest.json"
    expect(response.status).to eq(200)
    # `check_readonly_mode` runs via the ReadOnlyMixin before_action; the
    # preloader reads @archive_mode when serving anonymous data.
    preloaded = JSON.parse(response.body)
    expect(preloaded).to be_present
  end

  describe "write endpoints" do
    before { sign_in(user) }

    it "blocks a non-allowlisted POST with the archive error message" do
      post "/drafts.json", params: { draft_key: "new_topic", sequence: 0, data: "{}" }
      expect(response.status).to eq(503)
      expect(response.parsed_body["errors"]).to include(I18n.t("archive_mode_enabled"))
    end
  end

  describe "login" do
    before { SiteSetting.enable_local_logins_via_email = true }

    it "allows email login" do
      token = Fabricate(:email_token, user: user, scope: EmailToken.scopes[:email_login])
      post "/session/email-login/#{token.token}.json"
      expect(response.status).to eq(200)
      expect(session[:current_user_id]).to eq(user.id)
    end

    it "allows the post-login /login redirect helper" do
      post "/login", params: { redirect: "/" }
      expect(response).to redirect_to("/")
    end
  end

  describe "logout" do
    before { sign_in(user) }

    it "allows logout (does not raise Discourse::ReadOnly)" do
      delete "/session/#{user.username}.json"
      expect(response.status).not_to eq(503)
    end
  end

  context "when another readonly reason is also active" do
    before { Discourse.enable_readonly_mode(Discourse::USER_READONLY_MODE_KEY) }

    it "reports archive mode as no longer the effective mode" do
      expect(Discourse.archive_mode_active?).to eq(false)
    end

    it "blocks login (the archive carve-out disappears)" do
      token = Fabricate(:email_token, user: user, scope: EmailToken.scopes[:email_login])
      SiteSetting.enable_local_logins_via_email = true
      post "/session/email-login/#{token.token}.json"
      expect(response.status).to eq(503)
      expect(response.parsed_body["errors"]).to include(I18n.t("read_only_mode_enabled"))
    end
  end
end
