# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::ConversationStar, type: :model do
  fab!(:user)
  fab!(:topic, :private_message_topic)

  it "requires a user" do
    star = described_class.new(topic: topic)

    expect(star).not_to be_valid
    expect(star.errors[:user_id]).to be_present
  end

  it "requires a topic" do
    star = described_class.new(user: user)

    expect(star).not_to be_valid
    expect(star.errors[:topic_id]).to be_present
  end

  it "enforces uniqueness per user and topic" do
    described_class.create!(user: user, topic: topic)

    duplicate = described_class.new(user: user, topic: topic)
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:topic_id]).to be_present
  end

  it "allows different users to star the same topic" do
    described_class.create!(user: user, topic: topic)

    expect(described_class.new(user: Fabricate(:user), topic: topic)).to be_valid
  end
end
