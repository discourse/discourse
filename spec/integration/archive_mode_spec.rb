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

  describe "non-controller write paths" do
    it "blocks PostCreator (covers email-in, chat, jobs, moderator posts)" do
      creator =
        PostCreator.new(user, title: "Frozen topic", raw: "Some body content here for the test.")
      expect { creator.create! }.to raise_error(Discourse::SiteArchived)
    end

    it "blocks invite-based account creation (InviteRedeemer)" do
      invite = Fabricate(:invite, email: "newperson@example.com")
      expect do
        InviteRedeemer.create_user_from_invite(
          email: "newperson@example.com",
          invite: invite,
          email_verified: true,
        )
      end.to raise_error(Discourse::SiteArchived)
    end

    it "blocks new-user creation via DiscourseConnect (SSO first-time login)" do
      sso = DiscourseConnect.new(server_session: {})
      sso.external_id = "unique_external_id_123"
      sso.email = "new_sso_user@example.com"
      sso.username = "new_sso_user"
      sso.name = "New SSO User"
      expect { sso.lookup_or_create_user("127.0.0.1") }.to raise_error(Discourse::SiteArchived)
    end

    it "still lets existing users log in via DiscourseConnect" do
      existing = Fabricate(:user, email: "existing@example.com")
      sso = DiscourseConnect.new(server_session: {})
      sso.external_id = "existing_external_id"
      sso.email = "existing@example.com"
      sso.username = existing.username
      expect { sso.lookup_or_create_user("127.0.0.1") }.not_to raise_error
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
