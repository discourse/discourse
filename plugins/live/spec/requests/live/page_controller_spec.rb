# frozen_string_literal: true

require "rails_helper"

RSpec.describe Live::PageController do
  fab!(:staff, :admin)
  fab!(:user)
  fab!(:room) { Fabricate(:live_room, creator: staff, public: true) }

  before do
    SiteSetting.live_enabled = true
    SiteSetting.live_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
  end

  describe "#show" do
    it "renders the app shell for a visible room" do
      sign_in(user)

      get "/live/r/#{room.slug}"

      expect(response.status).to eq(200)
      expect(response.body).to include("discourse")
    end

    it "renders the app shell for an invite link carrying the inviter's username" do
      sign_in(user)

      get "/live/r/#{room.slug}/invited-by/#{staff.username_lower}"

      expect(response.status).to eq(200)
    end

    it "renders the app shell for an invite link when the inviter's username contains a period" do
      staff.update!(username: "alice.smith")
      sign_in(user)

      get "/live/r/#{room.slug}/invited-by/#{staff.username_lower}"

      expect(response.status).to eq(200)
    end

    it "returns 404 for an unknown slug" do
      sign_in(user)

      get "/live/r/not-a-room"

      expect(response.status).to eq(404)
    end

    it "rejects users who cannot see the room" do
      private_room = Fabricate(:live_room, creator: staff, public: false)
      sign_in(user)

      get "/live/r/#{private_room.slug}"

      expect(response.status).to eq(403)
    end

    it "renders for anonymous visitors when anonymous visitors are admitted" do
      get "/live/r/#{room.slug}"

      expect(response.status).to eq(200)
    end

    it "rejects anonymous visitors when access is restricted to a group" do
      SiteSetting.live_allowed_groups = "#{Group::AUTO_GROUPS[:trust_level_2]}"

      get "/live/r/#{room.slug}"

      expect(response.status).to eq(403)
    end
  end
end
