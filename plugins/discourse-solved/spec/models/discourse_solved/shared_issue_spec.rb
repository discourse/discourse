# frozen_string_literal: true

RSpec.describe DiscourseSolved::SharedIssue, type: :model do
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

  it "is deleted when its user is destroyed" do
    Fabricate(:shared_issue, topic:, user:)
    expect { user.destroy! }.to change { described_class.where(user_id: user.id).count }.to(0)
  end

  it "is deleted when its topic is destroyed" do
    Fabricate(:shared_issue, topic:, user:)
    expect { topic.destroy! }.to change { described_class.where(topic_id: topic.id).count }.to(0)
  end
end
