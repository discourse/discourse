# frozen_string_literal: true

RSpec.describe ReviewableClaimedTopic, type: :model do
  it "respects the uniqueness constraint" do
    topic = Fabricate(:topic)

    ct = ReviewableClaimedTopic.new(topic_id: topic.id, user_id: Fabricate(:user).id)
    expect(ct.save).to eq(true)

    ct = ReviewableClaimedTopic.new(topic_id: topic.id, user_id: Fabricate(:user).id)
    expect(ct.save).to eq(false)
  end

  describe "#log_topic_history" do
    fab!(:topic)
    fab!(:moderator)
    fab!(:pending_reviewable) { Fabricate(:reviewable_flagged_post, topic:) }
    fab!(:resolved_reviewable) { Fabricate(:reviewable_flagged_post, topic:, status: :approved) }

    it "logs on every pending reviewable of the topic, never on resolved ones" do
      claim = Fabricate(:reviewable_claimed_topic, topic:, user: moderator)

      claim.log_topic_history(:claimed, moderator)

      expect(pending_reviewable.history.claimed.size).to eq(1)
      expect(resolved_reviewable.history.claimed).to be_empty
    end

    it "logs nothing for an automatic claim, which is a transient lock" do
      claim = Fabricate(:reviewable_claimed_topic, topic:, user: moderator, automatic: true)

      claim.log_topic_history(:claimed, moderator)

      expect(pending_reviewable.history.claimed).to be_empty
    end
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
      expect(result.keys).to contain_exactly(topic1.id, topic2.id)
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
      expect(result.keys).to contain_exactly(topic2.id)
    end
  end
end
