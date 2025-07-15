# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::Patreon::Seed do
  it "should seed contents correctly" do
    described_class.seed_content!
    group = Group.last
    expect(group.name).to eq("patrons")
    expect(group.flair_upload).to be_present
    expect(Badge.last.name).to eq("Patron")
    expect(::Patreon.get("filters")).to eq(group.id.to_s => ["0"])
  end

  it "should not raise error if group already exists" do
    group = Fabricate(:group, name: "patrons")
    described_class.seed_content!
    expect(::Patreon.get("filters")).to eq(group.id.to_s => ["0"])
  end

  it "should not raise error if badge already exists" do
    Fabricate(:badge, name: "Patron")
    described_class.seed_content!
  end
end
