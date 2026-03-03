# frozen_string_literal: true

describe PostVoting::TopicListItemSerializerExtension do
  fab!(:user)
  fab!(:topic) { Fabricate(:topic, subtype: Topic::POST_VOTING_SUBTYPE) }
  fab!(:post) { Fabricate(:post, topic: topic, qa_vote_count: 3) }

  before do
    SiteSetting.post_voting_enabled = true
    topic.update!(archetype: Archetype.default)
  end

  context "when post voting is disabled" do
    before { SiteSetting.post_voting_serialize_topic_votes_count = false }

    it "does not include vote count in serialized output" do
      json = described_class.new(topic, scope: Guardian.new(user)).as_json
      expect(json[:topic_list_item][:topic_vote_count]).to be_nil
    end
  end

  context "when post voting is enabled" do
    before { SiteSetting.post_voting_serialize_topic_votes_count = true }

    it "includes topic_vote_count when mode is total" do
      SiteSetting.post_voting_topic_vote_count_mode = "total"
      json = described_class.new(topic, scope: Guardian.new(user)).as_json
      expect(json[:topic_list_item][:topic_vote_count]).to eq(3)
    end

    it "includes first post vote count when mode is first_post" do
      SiteSetting.post_voting_topic_vote_count_mode = "first_post"
      topic.first_post.update!(qa_vote_count: 5)
      json = described_class.new(topic, scope: Guardian.new(user)).as_json
      expect(json[:topic_list_item][:topic_vote_count]).to eq(5)
    end

    it "returns 0 if there are no votes" do
      topic.posts.update_all(qa_vote_count: 0)
      SiteSetting.post_voting_topic_vote_count_mode = "total"
      json = described_class.new(topic, scope: Guardian.new(user)).as_json
      expect(json[:topic_list_item][:topic_vote_count]).to eq(0)
    end
  end
end
