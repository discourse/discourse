# frozen_string_literal: true

RSpec.describe BadgesController do
  fab!(:badge)
  fab!(:user)

  before { SiteSetting.enable_badges = true }

  describe "#message_recipients" do
    fab!(:moderator)
    fab!(:repeatable_badge) { Fabricate(:badge, multiple_grant: true) }
    fab!(:inactive_user) { Fabricate(:user, active: false) }

    def get_recipients
      get "/badges/#{repeatable_badge.id}/recipients/for-message.json",
          headers: {
            "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest",
          }
    end

    it "requires the site to opt in" do
      sign_in(moderator)
      get_recipients
      expect(response.status).to eq(404)
    end

    context "when the site opts in" do
      before { SiteSetting.enable_badge_holder_pm_recipients = true }

      it "denies regular users" do
        sign_in(user)
        get_recipients
        expect(response.status).to eq(403)
      end

      it "requires badges to be enabled" do
        SiteSetting.enable_badges = false
        sign_in(moderator)
        get_recipients
        expect(response.status).to eq(404)
      end

      it "returns active holders once and excludes the sender" do
        2.times { |seq| Fabricate(:user_badge, badge: repeatable_badge, user:, seq:) }
        Fabricate(:user_badge, badge: repeatable_badge, user: inactive_user)
        Fabricate(:user_badge, badge: repeatable_badge, user: moderator)
        sign_in(moderator)

        get_recipients

        expect(response.status).to eq(200)
        expect(response.parsed_body["usernames"]).to eq([user.username])
      end

      it "rejects a disabled badge" do
        repeatable_badge.update!(enabled: false)
        sign_in(moderator)
        get_recipients
        expect(response.status).to eq(404)
      end
    end
  end

  describe "#index" do
    it "returns all badges" do
      get "/badges.json"

      expect(response.status).to eq(200)
      parsed = response.parsed_body
      expect(parsed["badges"].length).to eq(Badge.enabled.count)
      expect(response.headers["X-Robots-Tag"]).to eq("noindex")
    end

    it "does not expose disabled badges via XHR requests" do
      disabled_badge = Fabricate(:badge, enabled: false)

      get "/badges.json", headers: { "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest" }

      expect(response.status).to eq(200)
      badge_ids = response.parsed_body["badges"].map { |b| b["id"] }
      expect(badge_ids).not_to include(disabled_badge.id)
    end

    it "does not expose non-listable badges via XHR requests" do
      non_listable_badge = Fabricate(:badge, listable: false)

      get "/badges.json", headers: { "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest" }

      expect(response.status).to eq(200)
      badge_ids = response.parsed_body["badges"].map { |b| b["id"] }
      expect(badge_ids).not_to include(non_listable_badge.id)
    end

    it "allows staff to see disabled and non-listable badges via XHR requests" do
      admin = Fabricate(:admin)
      disabled_badge = Fabricate(:badge, enabled: false)
      non_listable_badge = Fabricate(:badge, listable: false)

      sign_in(admin)
      get "/badges.json", headers: { "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest" }

      expect(response.status).to eq(200)
      badge_ids = response.parsed_body["badges"].map { |b| b["id"] }
      expect(badge_ids).to include(disabled_badge.id)
      expect(badge_ids).to include(non_listable_badge.id)
    end

    it "filters disabled and non-listable badges for staff on non-XHR requests" do
      admin = Fabricate(:admin)
      disabled_badge = Fabricate(:badge, enabled: false)
      non_listable_badge = Fabricate(:badge, listable: false)

      sign_in(admin)
      get "/badges.json"

      expect(response.status).to eq(200)
      badge_ids = response.parsed_body["badges"].map { |b| b["id"] }
      expect(badge_ids).not_to include(disabled_badge.id)
      expect(badge_ids).not_to include(non_listable_badge.id)
    end

    it "filters disabled and non-listable badges for staff when only_listable param is true" do
      admin = Fabricate(:admin)
      disabled_badge = Fabricate(:badge, enabled: false)
      non_listable_badge = Fabricate(:badge, listable: false)

      sign_in(admin)
      get "/badges.json",
          params: {
            only_listable: "true",
          },
          headers: {
            "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest",
          }

      expect(response.status).to eq(200)
      badge_ids = response.parsed_body["badges"].map { |b| b["id"] }
      expect(badge_ids).not_to include(disabled_badge.id)
      expect(badge_ids).not_to include(non_listable_badge.id)
    end

    context "with an API key" do
      let(:api_key) { Fabricate(:api_key, user:) }

      def list_badges
        get "/badges.json",
            headers: {
              "HTTP_API_KEY" => api_key.key,
              "HTTP_API_USERNAME" => user.username,
            }
      end

      it "allows listing badges with the badges -> list scope" do
        Fabricate(:api_key_scope, resource: "badges", action: "list", api_key_id: api_key.id)

        list_badges

        expect(response.status).to eq(200)
        expect(response.parsed_body["badges"]).to be_present
      end

      it "denies listing badges with a non-matching scope" do
        Fabricate(:api_key_scope, resource: "badges", action: "show", api_key_id: api_key.id)

        list_badges

        expect(response.status).to eq(403)
      end

      it "allows listing badges with the badges -> list scope when login is required" do
        SiteSetting.login_required = true
        Fabricate(:api_key_scope, resource: "badges", action: "list", api_key_id: api_key.id)

        list_badges

        expect(response.status).to eq(200)
        expect(response.parsed_body["badges"]).to be_present
      end
    end
  end

  describe "#show" do
    it "returns the badge" do
      get "/badges/#{badge.id}.json"
      expect(response.status).to eq(200)
      parsed = response.parsed_body
      expect(parsed["badge"]).to be_present
    end

    it "marks the notification as viewed" do
      sign_in(user)
      user_badge = BadgeGranter.grant(badge, user)
      expect(user_badge.notification.read).to eq(false)
      get "/badges/#{badge.id}.json"
      expect(user_badge.notification.reload.read).to eq(true)
    end

    it "renders rss feed of a badge" do
      get "/badges/#{badge.id}.rss"
      expect(response.status).to eq(200)
      expect(response.media_type).to eq("application/rss+xml")
    end

    it "does not include hidden profiles in the rss feed" do
      hidden_user = Fabricate(:user)
      hidden_user.user_stat.update!(post_count: 1)
      hidden_user.user_option.update!(hide_profile: true)
      visible_user = Fabricate(:user)
      visible_user.user_stat.update!(post_count: 1)
      [visible_user, hidden_user].each do |grantee|
        Fabricate(:user_badge, badge: badge, user: grantee, granted_by: Discourse.system_user)
      end

      get "/badges/#{badge.id}.rss"

      expect(response.status).to eq(200)
      expect(response.body).to include(visible_user.username)
      expect(response.body).not_to include(hidden_user.username)
    end
  end

  describe "user profiles" do
    let(:titled_badge) { Fabricate(:badge, name: "Protector of the Realm", allow_title: true) }
    let!(:grant) do
      UserBadge.create!(
        user_id: user.id,
        badge_id: titled_badge.id,
        granted_at: 1.minute.ago,
        granted_by_id: -1,
      )
    end

    it "can be assigned as a title by the user" do
      sign_in(user)
      put "/u/#{user.username}/preferences/badge_title.json", params: { user_badge_id: grant.id }
      expect(response.status).to eq(200)
      user.reload

      expect(user.title).to eq(titled_badge.display_name)
      expect(user.user_profile.granted_title_badge_id).to eq(titled_badge.id)
    end
  end

  describe "destroy" do
    let(:admin) { Fabricate(:admin) }

    context "while assigned as a title" do
      let(:titled_badge) { Fabricate(:badge, name: "Protector of the Realm", allow_title: true) }
      let!(:grant) do
        UserBadge.create!(
          user_id: user.id,
          badge_id: titled_badge.id,
          granted_at: 1.minute.ago,
          granted_by_id: -1,
        )
      end

      before do
        sign_in(user)
        put "/u/#{user.username}/preferences/badge_title.json", params: { user_badge_id: grant.id }
        user.reload
        sign_out
      end

      it "succeeds and unassigns the title from the user" do
        expect(user.title).to eq(titled_badge.display_name)

        sign_in(admin)
        badge_id = titled_badge.id

        delete "/admin/badges/#{titled_badge.id}.json"
        expect(response.status).to be(200)
        expect(Badge.find_by(id: badge_id)).to be(nil)

        user.reload
        expect(user.title).to_not eq(titled_badge.display_name)
        expect(user.user_profile.granted_title_badge_id).to eq(nil)
      end
    end
  end
end
