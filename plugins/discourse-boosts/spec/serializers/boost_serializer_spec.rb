# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseBoosts::BoostSerializer do
  fab!(:post_author, :user)
  fab!(:boost_author, :user)
  fab!(:post) { Fabricate(:post, user: post_author) }
  fab!(:boost) { Fabricate(:boost, post: post, user: boost_author) }

  before { SiteSetting.discourse_boosts_enabled = true }

  def serialize(user)
    described_class.new(boost, scope: Guardian.new(user), root: false).as_json
  end

  describe "#can_flag" do
    it "returns true for a user who is not the boost author" do
      expect(serialize(Fabricate(:user))[:can_flag]).to eq(true)
    end

    it "returns false for the boost author" do
      expect(serialize(boost_author)[:can_flag]).to eq(false)
    end

    it "returns false for anonymous users" do
      expect(serialize(nil)[:can_flag]).to eq(false)
    end
  end

  describe "#user_flag_status" do
    it "returns nil when user has not flagged the boost" do
      expect(serialize(Fabricate(:user))[:user_flag_status]).to be_nil
    end
  end

  describe "can_delete" do
    it "is true for the boost author" do
      expect(serialize(boost_author)[:can_delete]).to eq(true)
    end

    it "is false for another regular user" do
      expect(serialize(Fabricate(:user))[:can_delete]).to eq(false)
    end

    it "is true for an admin" do
      expect(serialize(Fabricate(:admin))[:can_delete]).to eq(true)
    end

    it "is true for a moderator" do
      expect(serialize(Fabricate(:moderator))[:can_delete]).to eq(true)
    end

    it "is falsey for an anonymous user" do
      expect(serialize(nil)[:can_delete]).to be_falsey
    end
  end
end
