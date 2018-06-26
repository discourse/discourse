require 'rails_helper'

describe UserBadgesController do
  let(:user) { Fabricate(:user) }
  let(:badge) { Fabricate(:badge) }

  context 'index' do
    let(:badge) { Fabricate(:badge, target_posts: true, show_posts: false) }
    it 'does not leak private info' do
      p = create_post
      UserBadge.create!(badge: badge, user: user, post_id: p.id, granted_by_id: -1, granted_at: Time.now)

      get "/user_badges.json", params: { badge_id: badge.id }
      expect(response.status).to eq(200)

      parsed = JSON.parse(response.body)
      expect(parsed["topics"]).to eq(nil)
      expect(parsed["badges"].length).to eq(1)
      expect(parsed["user_badge_info"]["user_badges"][0]["post_id"]).to eq(nil)
    end

    it "fails when badges are disabled" do
      SiteSetting.enable_badges = false
      get "/user_badges.json", params: { badge_id: badge.id }
      expect(response.status).to eq(404)
    end
  end

  context 'index' do
    let!(:user_badge) { UserBadge.create(badge: badge, user: user, granted_by: Discourse.system_user, granted_at: Time.now) }

    it 'requires username or badge_id to be specified' do
      get "/user_badges.json"
      expect(response.status).to eq(400)
    end

    it 'returns user_badges for a user' do
      get "/user-badges/#{user.username}.json"

      expect(response.status).to eq(200)
      parsed = JSON.parse(response.body)
      expect(parsed["user_badges"].length).to eq(1)
    end

    it 'returns user_badges for a badge' do
      get "/user_badges.json", params: { badge_id: badge.id }

      expect(response.status).to eq(200)
      parsed = JSON.parse(response.body)
      expect(parsed["user_badge_info"]["user_badges"].length).to eq(1)
    end

    it 'includes counts when passed the aggregate argument' do
      get "/user-badges/#{user.username}.json", params: {
        grouped: true
      }

      expect(response.status).to eq(200)
      parsed = JSON.parse(response.body)
      expect(parsed["user_badges"].first.has_key?('count')).to eq(true)
    end
  end

  context 'create' do
    it 'requires username to be specified' do
      post "/user_badges.json", params: { badge_id: badge.id }
      expect(response.status).to eq(400)
    end

    it 'does not allow regular users to grant badges' do
      sign_in(Fabricate(:user))

      post "/user_badges.json", params: {
        badge_id: badge.id, username: user.username
      }

      expect(response.status).to eq(403)
    end

    it 'grants badges from staff' do
      admin = Fabricate(:admin)
      post_1 = create_post

      sign_in(admin)

      post "/user_badges.json", params: {
        badge_id: badge.id,
        username: user.username,
        reason: Discourse.base_url + post_1.url
      }

      expect(response.status).to eq(200)

      user_badge = UserBadge.find_by(user: user, badge: badge)

      expect(user_badge).to be_present
      expect(user_badge.granted_by).to eq(admin)
      expect(user_badge.post_id).to eq(post_1.id)
      expect(UserHistory.where(acting_user: admin, target_user: user).count).to eq(1)
    end

    it 'does not grant badges from regular api calls' do
      Fabricate(:api_key, user: user)

      post "/user_badges.json", params: {
        badge_id: badge.id, username: user.username, api_key: user.api_key.key
      }

      expect(response.status).to eq(403)
    end

    it 'grants badges from master api calls' do
      api_key = Fabricate(:api_key)

      post "/user_badges.json", params: {
        badge_id: badge.id, username: user.username, api_key: api_key.key, api_username: "system"
      }

      expect(response.status).to eq(200)
      user_badge = UserBadge.find_by(user: user, badge: badge)
      expect(user_badge).to be_present
      expect(user_badge.granted_by).to eq(Discourse.system_user)
      expect(UserHistory.where(acting_user: Discourse.system_user, target_user: user).count).to eq(0)
    end

    it 'will trigger :user_badge_granted' do
      sign_in(Fabricate(:admin))

      events = DiscourseEvent.track_events do
        post "/user_badges.json", params: {
          badge_id: badge.id, username: user.username
        }
      end.map { |event| event[:event_name] }

      expect(events).to include(:user_badge_granted)
    end
  end

  context 'destroy' do
    let!(:user_badge) { UserBadge.create(badge: badge, user: user, granted_by: Discourse.system_user, granted_at: Time.now) }

    it 'checks that the user is authorized to revoke a badge' do
      delete "/user_badges/#{user_badge.id}.json"
      expect(response.status).to eq(403)
    end

    it 'revokes the badge' do
      admin = Fabricate(:admin)
      sign_in(admin)
      delete "/user_badges/#{user_badge.id}.json"

      expect(response.status).to eq(200)
      expect(UserBadge.find_by(id: user_badge.id)).to eq(nil)
      expect(UserHistory.where(acting_user: admin, target_user: user).count).to eq(1)
    end

    it 'will trigger :user_badge_removed' do
      sign_in(Fabricate(:admin))

      events = DiscourseEvent.track_events do
        delete "/user_badges/#{user_badge.id}.json"
      end.map { |event| event[:event_name] }

      expect(events).to include(:user_badge_removed)
    end
  end
end
