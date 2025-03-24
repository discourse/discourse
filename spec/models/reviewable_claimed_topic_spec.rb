# frozen_string_literal: true

RSpec.describe ReviewableClaimedTopic, type: :model do
  it "respects the uniqueness constraint" do
    topic = Fabricate(:topic)

    ct = ReviewableClaimedTopic.new(topic_id: topic.id, user_id: Fabricate(:user).id)
    expect(ct.save).to eq(true)

    ct = ReviewableClaimedTopic.new(topic_id: topic.id, user_id: Fabricate(:user).id)
    expect(ct.save).to eq(false)
  end

  describe "#claimed_hash" do
    it "returns the all the claimed topics when reviewable claiming is enabled" do
      SiteSetting.reviewable_claiming = "optional"

      topic1 = Fabricate(:topic)
      topic2 = Fabricate(:topic)

      ReviewableClaimedTopic.create(topic_id: topic1.id, user_id: Fabricate(:user).id)
      ReviewableClaimedTopic.create(
        topic_id: topic2.id,
        user_id: Fabricate(:user).id,
        automatic: true,
      )

      result = ReviewableClaimedTopic.claimed_hash([topic1.id, topic2.id])
      expect(result[topic1.id].topic_id).to eq(topic1.id)
      expect(result[topic2.id].topic_id).to eq(topic2.id)
    end

    it "only returns the automatic claimed topics when reviewable claiming is disabled" do
      SiteSetting.reviewable_claiming = "disabled"

      topic1 = Fabricate(:topic)
      topic2 = Fabricate(:topic)

      ReviewableClaimedTopic.create(topic_id: topic1.id, user_id: Fabricate(:user).id)
      ReviewableClaimedTopic.create(
        topic_id: topic2.id,
        user_id: Fabricate(:user).id,
        automatic: true,
      )

      result = ReviewableClaimedTopic.claimed_hash([topic1.id, topic2.id])
      expect(result[topic2.id].topic_id).to eq(topic2.id)
    end
  end
end
