# frozen_string_literal: true

require 'rails_helper'

describe AssociatedGroup do
  let(:user) { Fabricate(:user) }
  let(:associated_group) { Fabricate(:associated_group) }
  let(:group) { Fabricate(:group) }

  it "generates a label" do
    ag = described_class.new(name: "group1", provider_name: "google")
    expect(ag.label).to eq("google:group1")
  end

  it "detects whether any auth providers provide associated groups" do
    SiteSetting.enable_google_oauth2_logins = true
    SiteSetting.google_oauth2_hd = 'domain.com'
    SiteSetting.google_oauth2_hd_groups = false
    expect(described_class.has_provider?).to eq(false)

    SiteSetting.google_oauth2_hd_groups = true
    expect(described_class.has_provider?).to eq(true)
  end

  context "cleanup!" do
    before do
      associated_group.last_used = 8.days.ago
      associated_group.save
    end

    it "deletes associated groups not used in over a week" do
      described_class.cleanup!
      expect(described_class.exists?(associated_group.id)).to eq(false)
    end

    it "doesnt delete associated groups associated with groups" do
      GroupAssociatedGroup.create(group_id: group.id, associated_group_id: associated_group.id)
      described_class.cleanup!
      expect(described_class.exists?(associated_group.id)).to eq(true)
    end

    it "doesnt delete associated groups associated with users" do
      UserAssociatedGroup.create(user_id: user.id, associated_group_id: associated_group.id)
      described_class.cleanup!
      expect(described_class.exists?(associated_group.id)).to eq(true)
    end
  end
end
