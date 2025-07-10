# frozen_string_literal: true

require "rails_helper"
require_relative "../fabricators/reaction_fabricator.rb"
require_relative "../fabricators/reaction_user_fabricator.rb"

describe BadgeGranter do
  fab!(:user)
  fab!(:post)
  fab!(:reaction) { Fabricate(:reaction, post: post) }
  fab!(:reaction_user) { Fabricate(:reaction_user, reaction: reaction, user: user, post: post) }
  let(:badge) { Badge.find_by(name: "First Reaction") }

  before do
    SiteSetting.discourse_reactions_enabled = true
    BadgeGranter.enable_queue
  end

  after do
    BadgeGranter.disable_queue
    BadgeGranter.clear_queue!
  end

  describe "First Reaction" do
    it "badge is available" do
      expect(badge).not_to eq(nil)
    end

    it "badge query is not broken" do
      backfill = BadgeGranter.backfill(badge)

      expect(backfill).to eq(true)
    end

    it "can backfill the badge" do
      UserBadge.destroy_all
      BadgeGranter.backfill(badge)

      b = UserBadge.find_by(user_id: user.id)

      expect(b.post_id).to eq(post.id)
      expect(b.badge_id).to eq(badge.id)
    end
  end
end
