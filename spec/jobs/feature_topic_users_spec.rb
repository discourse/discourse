require 'rails_helper'
require_dependency 'jobs/base'
require 'jobs/regular/process_post'

describe Jobs::FeatureTopicUsers do

  it "raises an error without a topic_id" do
    expect { Jobs::FeatureTopicUsers.new.execute({}) }.to raise_error(Discourse::InvalidParameters)
  end

  it "raises no error with a missing topic_id" do
    Jobs::FeatureTopicUsers.new.execute(topic_id: 123)
  end

  context 'with a topic' do
    let!(:post) { create_post }
    let(:topic) { post.topic }
    let!(:coding_horror) { Fabricate(:coding_horror) }
    let!(:evil_trout) { Fabricate(:evil_trout) }
    let!(:second_post) { create_post(topic: topic, user: coding_horror)}
    let!(:third_post) { create_post(topic: topic, user: evil_trout)}

    it "won't feature the OP" do
      Jobs::FeatureTopicUsers.new.execute(topic_id: topic.id)
      expect(topic.reload.featured_user_ids.include?(topic.user_id)).to eq(false)
    end

    it "features the second poster" do
      Jobs::FeatureTopicUsers.new.execute(topic_id: topic.id)
      expect(topic.reload.featured_user_ids.include?(coding_horror.id)).to eq(true)
    end

    it "won't feature the last poster" do
      Jobs::FeatureTopicUsers.new.execute(topic_id: topic.id)
      expect(topic.reload.featured_user_ids.include?(evil_trout.id)).to eq(false)
    end

  end

  context "participant count" do

    let!(:post) { create_post }
    let(:topic) { post.topic }


    it "it works as expected" do

      # It has 1 participant after creation
      expect(topic.participant_count).to eq(1)

      # It still has 1 after featuring
      Jobs::FeatureTopicUsers.new.execute(topic_id: topic.id)
      expect(topic.reload.participant_count).to eq(1)

      # If the OP makes another post, it's still 1.
      create_post(topic: topic, user: post.user)
      Jobs::FeatureTopicUsers.new.execute(topic_id: topic.id)
      expect(topic.reload.participant_count).to eq(1)

      # If another users posts, it's 2.
      create_post(topic: topic, user: Fabricate(:evil_trout))
      Jobs::FeatureTopicUsers.new.execute(topic_id: topic.id)
      expect(topic.reload.participant_count).to eq(2)

    end

  end

end
