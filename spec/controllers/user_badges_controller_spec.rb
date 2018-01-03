require 'rails_helper'

describe UserBadgesController do
  let(:user) { Fabricate(:user) }
  let(:badge) { Fabricate(:badge) }

  context 'index' do
    let(:badge) { Fabricate(:badge, target_posts: true, show_posts: false) }
    it 'does not leak private info' do
      p = create_post
      UserBadge.create(badge: badge, user: user, post_id: p.id, granted_by_id: -1, granted_at: Time.now)

      get :index, params: { badge_id: badge.id }, format: :json
      expect(response).to be_success

      parsed = JSON.parse(response.body)
      expect(parsed["topics"]).to eq(nil)
      expect(parsed["badges"].length).to eq(1)
      expect(parsed["user_badge_info"]["user_badges"][0]["post_id"]).to eq(nil)
    end

    it "fails when badges are disabled" do
      SiteSetting.enable_badges = false
      get :index, params: { badge_id: badge.id }, format: :json
      expect(response.status).to eq(404)
    end
  end

  context 'index' do
    let!(:user_badge) { UserBadge.create(badge: badge, user: user, granted_by: Discourse.system_user, granted_at: Time.now) }

    it 'requires username or badge_id to be specified' do
      expect do
        get :index, format: :json
      end.to raise_error(ActionController::ParameterMissing)
    end

    it 'returns user_badges for a user' do
      get :username, params: { username: user.username }, format: :json

      expect(response.status).to eq(200)
      parsed = JSON.parse(response.body)
      expect(parsed["user_badges"].length).to eq(1)
    end

    it 'returns user_badges for a badge' do
      get :index, params: { badge_id: badge.id }, format: :json

      expect(response.status).to eq(200)
      parsed = JSON.parse(response.body)
      expect(parsed["user_badge_info"]["user_badges"].length).to eq(1)
    end

    it 'includes counts when passed the aggregate argument' do
      get :username, params: {
        username: user.username, grouped: true
      }, format: :json

      expect(response.status).to eq(200)
      parsed = JSON.parse(response.body)
      expect(parsed["user_badges"].first.has_key?('count')).to eq(true)
    end
  end

  context 'create' do
    it 'requires username to be specified' do
      expect do
        post :create, params: { badge_id: badge.id }, format: :json
      end.to raise_error(ActionController::ParameterMissing)
    end

    it 'does not allow regular users to grant badges' do
      log_in_user Fabricate(:user)

      post :create, params: {
        badge_id: badge.id, username: user.username
      }, format: :json

      expect(response.status).to eq(403)
    end

    it 'grants badges from staff' do
      admin = Fabricate(:admin)
      post_1 = create_post

      log_in_user admin

      StaffActionLogger.any_instance.expects(:log_badge_grant).once

      post :create, params: {
        badge_id: badge.id,
        username: user.username,
        reason: Discourse.base_url + post_1.url
      }, format: :json

      expect(response.status).to eq(200)

      user_badge = UserBadge.find_by(user: user, badge: badge)

      expect(user_badge).to be_present
      expect(user_badge.granted_by).to eq(admin)
      expect(user_badge.post_id).to eq(post_1.id)
    end

    it 'does not grant badges from regular api calls' do
      Fabricate(:api_key, user: user)

      post :create, params: {
        badge_id: badge.id, username: user.username, api_key: user.api_key.key
      }, format: :json

      expect(response.status).to eq(403)
    end

    it 'grants badges from master api calls' do
      api_key = Fabricate(:api_key)
      StaffActionLogger.any_instance.expects(:log_badge_grant).never

      post :create, params: {
        badge_id: badge.id, username: user.username, api_key: api_key.key, api_username: "system"
      }, format: :json

      expect(response.status).to eq(200)
      user_badge = UserBadge.find_by(user: user, badge: badge)
      expect(user_badge).to be_present
      expect(user_badge.granted_by).to eq(Discourse.system_user)
    end

    it 'will trigger :user_badge_granted' do
      log_in :admin
      user

      event = DiscourseEvent.track_events do
        post :create, params: {
          badge_id: badge.id, username: user.username
        }, format: :json
      end.first

      expect(event[:event_name]).to eq(:user_badge_granted)
    end
  end

  context 'destroy' do
    let!(:user_badge) { UserBadge.create(badge: badge, user: user, granted_by: Discourse.system_user, granted_at: Time.now) }

    it 'checks that the user is authorized to revoke a badge' do
      delete :destroy, params: { id: user_badge.id }, format: :json
      expect(response.status).to eq(403)
    end

    it 'revokes the badge' do
      log_in :admin
      StaffActionLogger.any_instance.expects(:log_badge_revoke).once
      delete :destroy, params: { id: user_badge.id }, format: :json
      expect(response.status).to eq(200)
      expect(UserBadge.find_by(id: user_badge.id)).to eq(nil)
    end

    it 'will trigger :user_badge_removed' do
      log_in :admin

      event = DiscourseEvent.track_events do
        delete :destroy, params: { id: user_badge.id }, format: :json
      end.first

      expect(event[:event_name]).to eq(:user_badge_removed)
    end
  end
end
