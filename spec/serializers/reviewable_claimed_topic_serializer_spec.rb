# frozen_string_literal: true

RSpec.describe ReviewableClaimedTopicSerializer do
  fab!(:claimed_by_user) { Fabricate(:reviewable, topic: Fabricate(:topic)) }
  fab!(:admin)
  fab!(:reviewable_claimed_topic) do
    Fabricate(:reviewable_claimed_topic, topic: claimed_by_user.topic, user: admin)
  end

  it "serializes all the fields" do
    json =
      described_class.new(reviewable_claimed_topic, scope: Guardian.new(admin), root: nil).as_json

    expect(json[:id]).to eq(reviewable_claimed_topic.id)
    expect(json[:automatic]).to eq(reviewable_claimed_topic.automatic)
    expect(json[:user_id]).to eq(admin.id)
  end
end
