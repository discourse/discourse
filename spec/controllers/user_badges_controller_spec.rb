require 'spec_helper'

describe UserBadgesController do
  let(:user) { Fabricate(:user) }
  let(:badge) { Fabricate(:badge) }

  context 'index' do
    it 'does not leak private info' do
      badge = Fabricate(:badge, target_posts: true, show_posts: false)
      p = create_post
      UserBadge.create(badge: badge, user: user, post_id: p.id, granted_by_id: -1, granted_at: Time.now)

      xhr :get, :index, badge_id: badge.id
      expect(response.status).to eq(200)
      parsed = JSON.parse(response.body)
      expect(parsed["topics"]).to eq(nil)
      expect(parsed["user_badges"][0]["post_id"]).to eq(nil)
    end
  end

  context 'index' do
    let!(:user_badge) { UserBadge.create(badge: badge, user: user, granted_by: Discourse.system_user, granted_at: Time.now) }

    it 'requires username or badge_id to be specified' do
      expect { xhr :get, :index }.to raise_error
    end

    it 'returns user_badges for a user' do
      xhr :get, :username, username: user.username

      expect(response.status).to eq(200)
      parsed = JSON.parse(response.body)
      expect(parsed["user_badges"].length).to eq(1)
    end

    it 'returns user_badges for a badge' do
      xhr :get, :index, badge_id: badge.id

      expect(response.status).to eq(200)
      parsed = JSON.parse(response.body)
      expect(parsed["user_badges"].length).to eq(1)
    end

    it 'includes counts when passed the aggregate argument' do
      xhr :get, :username, username: user.username, grouped: true

      expect(response.status).to eq(200)
      parsed = JSON.parse(response.body)
      expect(parsed["user_badges"].first.has_key?('count')).to eq(true)
    end
  end

  context 'create' do
    it 'requires username to be specified' do
      expect { xhr :post, :create, badge_id: badge.id }.to raise_error
    end

    it 'does not allow regular users to grant badges' do
      log_in_user Fabricate(:user)
      xhr :post, :create, badge_id: badge.id, username: user.username
      expect(response.status).to eq(403)
    end

    it 'grants badges from staff' do
      admin = Fabricate(:admin)
      post = create_post

      log_in_user admin

      StaffActionLogger.any_instance.expects(:log_badge_grant).once

      xhr :post, :create, badge_id: badge.id,
                          username: user.username,
                          reason: Discourse.base_url + post.url

      expect(response.status).to eq(200)

      user_badge = UserBadge.find_by(user: user, badge: badge)

      expect(user_badge).to be_present
      expect(user_badge.granted_by).to eq(admin)
      expect(user_badge.post_id).to eq(post.id)
    end

    it 'does not grant badges from regular api calls' do
      Fabricate(:api_key, user: user)
      xhr :post, :create, badge_id: badge.id, username: user.username, api_key: user.api_key.key
      expect(response.status).to eq(403)
    end

    it 'grants badges from master api calls' do
      api_key = Fabricate(:api_key)
      StaffActionLogger.any_instance.expects(:log_badge_grant).never
      xhr :post, :create, badge_id: badge.id, username: user.username, api_key: api_key.key, api_username: "system"
      expect(response.status).to eq(200)
      user_badge = UserBadge.find_by(user: user, badge: badge)
      expect(user_badge).to be_present
      expect(user_badge.granted_by).to eq(Discourse.system_user)
    end

    it 'will trigger :user_badge_granted' do
      log_in :admin

      DiscourseEvent.expects(:trigger).with(:user_badge_granted, anything, anything).once
      xhr :post, :create, badge_id: badge.id, username: user.username
    end
  end

  context 'destroy' do
    let!(:user_badge) { UserBadge.create(badge: badge, user: user, granted_by: Discourse.system_user, granted_at: Time.now) }

    it 'checks that the user is authorized to revoke a badge' do
      xhr :delete, :destroy, id: user_badge.id
      expect(response.status).to eq(403)
    end

    it 'revokes the badge' do
      log_in :admin
      StaffActionLogger.any_instance.expects(:log_badge_revoke).once
      xhr :delete, :destroy, id: user_badge.id
      expect(response.status).to eq(200)
      expect(UserBadge.find_by(id: user_badge.id)).to eq(nil)
    end

    it 'will trigger :user_badge_removed' do
      log_in :admin
      DiscourseEvent.expects(:trigger).with(:user_badge_removed, anything, anything).once
      xhr :delete, :destroy, id: user_badge.id
    end
  end
end
