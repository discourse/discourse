require 'rails_helper'

describe BadgesController do
  let!(:badge) { Fabricate(:badge) }
  let(:user) { Fabricate(:user) }

  before do
    SiteSetting.enable_badges = true
  end

  context 'index' do
    it 'should return a list of all badges' do
      get :index, format: :json

      expect(response.status).to eq(200)
      parsed = JSON.parse(response.body)
      expect(parsed["badges"].length).to eq(Badge.count)
    end
  end

  context 'show' do
    it "should return a badge" do
      get :show, id: badge.id, format: :json
      expect(response.status).to eq(200)
      parsed = JSON.parse(response.body)
      expect(parsed["badge"]).to be_present
    end

    it "should mark the notification as viewed" do
      log_in_user(user)
      user_badge = BadgeGranter.grant(badge, user)
      expect(user_badge.notification.read).to eq(false)
      get :show, id: badge.id, format: :json
      expect(user_badge.notification.reload.read).to eq(true)
    end
  end
end
