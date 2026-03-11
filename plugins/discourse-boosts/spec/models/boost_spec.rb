# frozen_string_literal: true

require "rails_helper"

describe DiscourseBoosts::Boost do
  fab!(:post)
  fab!(:user)

  before { SiteSetting.discourse_boosts_enabled = true }

  describe "validations" do
    it "requires raw" do
      boost = DiscourseBoosts::Boost.new(post: post, user: user, raw: "", cooked: "")
      expect(boost).not_to be_valid
    end

    it "enforces max length of 16" do
      boost = DiscourseBoosts::Boost.new(post: post, user: user, raw: "a" * 17)
      expect(boost).not_to be_valid
    end

    it "allows valid boost" do
      boost = DiscourseBoosts::Boost.new(post: post, user: user, raw: "🎉")
      expect(boost).to be_valid
    end
  end

  describe ".cook" do
    it "cooks emoji" do
      cooked = DiscourseBoosts::Boost.cook(":tada:")
      expect(cooked).to include("emoji")
    end

    it "does not render links" do
      cooked = DiscourseBoosts::Boost.cook("https://example.com")
      expect(cooked).not_to include("<a")
    end
  end

  describe "auto-cooking" do
    it "cooks raw on save" do
      boost = DiscourseBoosts::Boost.create!(post: post, user: user, raw: ":tada:")
      expect(boost.cooked).to include("emoji")
    end
  end
end
