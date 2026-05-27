# frozen_string_literal: true

RSpec.describe Patreon::Seed do
  it "should seed contents correctly" do
    described_class.seed_content!
    group = Group.find_by(name: "patrons")
    expect(group).to be_present
    expect(group.flair_upload).to be_present
    expect(Badge.find_by(name: "Patron")).to be_present
    expect(Patreon.get("filters")).to eq(group.id.to_s => ["0"])
  end

  it "should not raise error if group already exists" do
    group = Fabricate(:group, name: "patrons")
    described_class.seed_content!
    expect(Patreon.get("filters")).to eq(group.id.to_s => ["0"])
  end

  it "should not raise error if badge already exists" do
    Badge.where(name: "Patron").first_or_create!(
      badge_type_id: 1,
      description: "test",
      listable: true,
    )
    expect { described_class.seed_content! }.not_to raise_error
  end
end
