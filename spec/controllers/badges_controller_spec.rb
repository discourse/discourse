require 'spec_helper'

describe BadgesController do
  let!(:badge) { Fabricate(:badge) }
  let(:user) { Fabricate(:user) }

  before do
    SiteSetting.enable_badges = true
  end

  context 'index' do
    it 'should return a list of all badges' do
      get :index, format: :json

      response.status.should == 200
      parsed = JSON.parse(response.body)
      parsed["badges"].length.should == Badge.count
    end
  end

  context 'show' do
    it "should return a badge" do
      get :show, id: badge.id, format: :json
      response.status.should == 200
      parsed = JSON.parse(response.body)
      parsed["badge"].should be_present
    end

    it "should mark the notification as viewed" do
      log_in_user(user)
      user_badge = BadgeGranter.grant(badge, user)
      user_badge.notification.read.should == false
      get :show, id: badge.id, format: :json
      user_badge.notification.reload.read.should == true
    end
  end
end
