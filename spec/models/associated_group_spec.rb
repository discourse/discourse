# frozen_string_literal: true

require 'rails_helper'

describe AssociatedGroup do
  it "generates a label" do
    provider_id = SecureRandom.hex(20)
    ag = described_class.new(name: "group1", provider_name: "google", provider_id: provider_id)
    expect(ag.label).to eq("group1:google:#{provider_id}")
  end

  it "detects whether any auth providers provide associated groups" do
    SiteSetting.enable_google_oauth2_logins = true
    SiteSetting.google_oauth2_hd = 'domain.com'
    SiteSetting.google_oauth2_hd_groups = false
    expect(described_class.has_provider?).to eq(false)

    SiteSetting.google_oauth2_hd_groups = true
    expect(described_class.has_provider?).to eq(true)
  end
end
