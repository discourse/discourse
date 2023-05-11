# frozen_string_literal: true

RSpec.describe BadgesController do
  fab!(:badge) { Fabricate(:badge) }
  fab!(:user) { Fabricate(:user) }

  before { SiteSetting.enable_badges = true }

  describe "#index" do
    it "should return a list of all badges" do
      get "/badges.json"

      expect(response.status).to eq(200)
      parsed = response.parsed_body
      expect(parsed["badges"].length).to eq(Badge.enabled.count)
      expect(response.headers["X-Robots-Tag"]).to eq("noindex")
    end
  end

  describe "#show" do
    it "should return a badge" do
      get "/badges/#{badge.id}.json"
      expect(response.status).to eq(200)
      parsed = response.parsed_body
      expect(parsed["badge"]).to be_present
    end

    it "should mark the notification as viewed" do
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
