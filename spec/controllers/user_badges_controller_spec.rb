require 'spec_helper'

describe UserBadgesController do
  let(:user) { Fabricate(:user) }
  let(:badge) { Fabricate(:badge) }

  context 'index' do
    let!(:user_badge) { UserBadge.create(badge: badge, user: user, granted_by: Discourse.system_user, granted_at: Time.now) }

    it 'requires username or badge_id to be specified' do
      expect { xhr :get, :index }.to raise_error
    end

    it 'returns user_badges for a user' do
      xhr :get, :index, username: user.username

      response.status.should == 200
      parsed = JSON.parse(response.body)
      parsed["user_badges"].length.should == 1
    end

    it 'returns user_badges for a badge' do
      xhr :get, :index, badge_id: badge.id

      response.status.should == 200
      parsed = JSON.parse(response.body)
      parsed["user_badges"].length.should == 1
    end

    it 'includes counts when passed the aggregate argument' do
      xhr :get, :index, username: user.username, grouped: true

      response.status.should == 200
      parsed = JSON.parse(response.body)
      parsed["user_badges"].first.has_key?('count').should be_true
    end
  end

  context 'create' do
    it 'requires username to be specified' do
      expect { xhr :post, :create, badge_id: badge.id }.to raise_error
    end

    it 'does not allow regular users to grant badges' do
      log_in_user Fabricate(:user)
      xhr :post, :create, badge_id: badge.id, username: user.username
      response.status.should == 403
    end

    it 'grants badges from staff' do
      admin = Fabricate(:admin)
      log_in_user admin
      StaffActionLogger.any_instance.expects(:log_badge_grant).once
      xhr :post, :create, badge_id: badge.id, username: user.username
      response.status.should == 200
      user_badge = UserBadge.find_by(user: user, badge: badge)
      user_badge.should be_present
      user_badge.granted_by.should eq(admin)
    end

    it 'does not grant badges from regular api calls' do
      Fabricate(:api_key, user: user)
      xhr :post, :create, badge_id: badge.id, username: user.username, api_key: user.api_key.key
      response.status.should == 403
    end

    it 'grants badges from master api calls' do
      api_key = Fabricate(:api_key)
      StaffActionLogger.any_instance.expects(:log_badge_grant).never
      xhr :post, :create, badge_id: badge.id, username: user.username, api_key: api_key.key, api_username: "system"
      response.status.should == 200
      user_badge = UserBadge.find_by(user: user, badge: badge)
      user_badge.should be_present
      user_badge.granted_by.should eq(Discourse.system_user)
    end
  end

  context 'destroy' do
    let!(:user_badge) { UserBadge.create(badge: badge, user: user, granted_by: Discourse.system_user, granted_at: Time.now) }

    it 'checks that the user is authorized to revoke a badge' do
      xhr :delete, :destroy, id: user_badge.id
      response.status.should == 403
    end

    it 'revokes the badge' do
      log_in :admin
      StaffActionLogger.any_instance.expects(:log_badge_revoke).once
      xhr :delete, :destroy, id: user_badge.id
      response.status.should == 200
      UserBadge.find_by(id: user_badge.id).should be_nil
    end
  end
end
