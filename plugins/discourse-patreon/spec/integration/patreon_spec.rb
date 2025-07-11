# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::Patreon do
  let(:user1) { Fabricate(:user) }
  let(:user2) { Fabricate(:user) }
  let(:group) { Fabricate(:group) }
  let(:filters) { { group.id.to_s => [] } }

  before do
    described_class.set("filters", filters)
    group.add(user1)
  end

  context "with donation prompt enabled" do
    before { SiteSetting.patreon_donation_prompt_enabled = true }

    it "should not show donation prompt to patrons" do
      expect(described_class.show_donation_prompt_to_user?(user1)).to eq(false)
    end

    it "should show donation prompt to non-patrons" do
      expect(described_class.show_donation_prompt_to_user?(user2)).to eq(true)
    end
  end

  context "with donation prompt disabled" do
    before { SiteSetting.patreon_donation_prompt_enabled = false }

    it "should show donation prompt to non-patrons" do
      expect(described_class.show_donation_prompt_to_user?(user2)).to eq(false)
    end
  end
end
