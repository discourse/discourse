# frozen_string_literal: true

require 'rails_helper'

describe BadgesController do
  fab!(:badge) { Fabricate(:badge) }
  fab!(:user) { Fabricate(:user) }

  before do
    SiteSetting.enable_badges = true
  end

  context 'index' do
    it 'should return a list of all badges' do
      get "/badges.json"

      expect(response.status).to eq(200)
      parsed = JSON.parse(response.body)
      expect(parsed["badges"].length).to eq(Badge.count)
    end
  end

  context 'show' do
    it "should return a badge" do
      get "/badges/#{badge.id}.json"
      expect(response.status).to eq(200)
      parsed = JSON.parse(response.body)
      expect(parsed["badge"]).to be_present
    end

    it "should mark the notification as viewed" do
      sign_in(user)
      user_badge = BadgeGranter.grant(badge, user)
      expect(user_badge.notification.read).to eq(false)
      get "/badges/#{badge.id}.json"
      expect(user_badge.notification.reload.read).to eq(true)
    end

    it 'renders rss feed of a badge' do
      get "/badges/#{badge.id}.rss"
      expect(response.status).to eq(200)
      expect(response.media_type).to eq('application/rss+xml')
    end
  end
end
