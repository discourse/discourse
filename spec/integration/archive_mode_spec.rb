# frozen_string_literal: true

RSpec.describe "Site archived" do
  fab!(:user)
  fab!(:admin)

  before { SiteSetting.site_archived = true }

  it "does not toggle Discourse.readonly_mode?" do
    expect(Discourse.readonly_mode?).to eq(false)
  end

  describe "write endpoints" do
    before { sign_in(user) }

    it "blocks a non-allowlisted POST with the site-archived error message" do
      post "/drafts.json", params: { draft_key: "new_topic", sequence: 0, data: "{}" }
      expect(response.status).to eq(503)
      expect(response.parsed_body["errors"]).to include(I18n.t("site_archived_error"))
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

    it "allows requesting an email login link (POST /u/email-login)" do
      post "/u/email-login.json", params: { login: user.username }
      expect(response.status).not_to eq(503)
    end

    it "allows the post-login /login redirect helper" do
      post "/login", params: { redirect: "/" }
      expect(response).to redirect_to("/")
    end
  end

  describe "logout" do
    before { sign_in(user) }

    it "allows logout" do
      delete "/session/#{user.username}.json"
      expect(response.status).not_to eq(503)
    end
  end

  describe "admin" do
    before { sign_in(admin) }

    it "lets an admin toggle site_archived back off" do
      put "/admin/site_settings/site_archived.json", params: { site_archived: false }
      expect(response.status).to eq(200).or eq(204)
      expect(SiteSetting.site_archived).to eq(false)
    end

    it "blocks admin updates to any other site setting while archived" do
      put "/admin/site_settings/title.json", params: { title: "New Title" }
      expect(response.status).to eq(503)
      expect(response.parsed_body["errors"]).to include(I18n.t("site_archived_error"))
      expect(SiteSetting.title).not_to eq("New Title")
    end

    it "blocks other admin writes (categories, users, etc.) while archived" do
      post "/categories.json", params: { name: "Frozen", color: "AB9364", text_color: "FFFFFF" }
      expect(response.status).to eq(503)
      expect(response.parsed_body["errors"]).to include(I18n.t("site_archived_error"))
    end

    it "allows backup operations (ops, not content)" do
      post "/admin/backups.json"
      expect(response.status).not_to eq(503)
    end
  end

  context "when an operational readonly reason is also active" do
    before { Discourse.enable_readonly_mode(Discourse::USER_READONLY_MODE_KEY) }
    after { Discourse.disable_readonly_mode(Discourse::USER_READONLY_MODE_KEY) }

    it "blocks a non-allowlisted login attempt with the read-only error (readonly takes precedence)" do
      post "/session.json", params: { login: user.username, password: "password" }
      expect(response.status).to eq(503)
      expect(response.parsed_body["errors"]).to include(I18n.t("read_only_mode_enabled"))
    end
  end
end
