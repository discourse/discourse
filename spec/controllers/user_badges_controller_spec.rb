require 'spec_helper'

describe UserBadgesController do
  let(:user) { Fabricate(:user) }
  let(:badge) { Fabricate(:badge) }

  context 'index' do
    before do
      @user_badge = BadgeGranter.grant(badge, user)
    end

    it 'requires username to be specified' do
      expect { xhr :get, :index }.to raise_error
    end

    it 'returns the user\'s badges' do
      xhr :get, :index, username: user.username

      response.status.should == 200
      parsed = JSON.parse(response.body)
      parsed["user_badges"].length.should == 1
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
      xhr :post, :create, badge_id: badge.id, username: user.username
      response.status.should == 200
      user_badge = UserBadge.where(user: user, badge: badge).first
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
      xhr :post, :create, badge_id: badge.id, username: user.username, api_key: api_key.key
      response.status.should == 200
      user_badge = UserBadge.where(user: user, badge: badge).first
      user_badge.should be_present
      user_badge.granted_by.should eq(Discourse.system_user)
    end
  end

  context 'destroy' do
    before do
      @user_badge = BadgeGranter.grant(badge, user)
    end

    it 'checks that the user is authorized to revoke a badge' do
      xhr :delete, :destroy, id: @user_badge.id
      response.status.should == 403
    end

    it 'revokes the badge' do
      log_in :admin
      xhr :delete, :destroy, id: @user_badge.id
      response.status.should == 200
      UserBadge.where(id: @user_badge.id).first.should be_nil
    end
  end
end
