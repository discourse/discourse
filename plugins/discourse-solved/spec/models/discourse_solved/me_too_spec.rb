# frozen_string_literal: true

RSpec.describe DiscourseSolved::MeToo, type: :model do
  fab!(:topic)
  fab!(:user)

  it "validates presence" do
    expect(described_class.new).not_to be_valid
  end

  it "is unique per topic and user" do
    described_class.create!(topic:, user:)
    duplicate = described_class.new(topic:, user:)
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:topic_id]).to include("has already been taken")
  end

  it "allows different users to flag the same topic" do
    described_class.create!(topic:, user:)
    other_user = Fabricate(:user)
    expect(described_class.new(topic:, user: other_user)).to be_valid
  end
end
