require 'spec_helper'
require_dependency 'jobs/base'
require 'jobs/regular/process_post'

describe Jobs::FeatureTopicUsers do

  it "raises an error without a topic_id" do
    lambda { Jobs::FeatureTopicUsers.new.execute({}) }.should raise_error(Discourse::InvalidParameters)
  end

  it "raises an error with a missing topic_id" do
    lambda { Jobs::FeatureTopicUsers.new.execute(topic_id: 123) }.should raise_error(Discourse::InvalidParameters)
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
      topic.reload.featured_user_ids.include?(topic.user_id).should be_false
    end

    it "features the second poster" do
      Jobs::FeatureTopicUsers.new.execute(topic_id: topic.id)
      topic.reload.featured_user_ids.include?(coding_horror.id).should be_true
    end

    it "will not feature the second poster if we supply their post to be ignored" do
      Jobs::FeatureTopicUsers.new.execute(topic_id: topic.id, except_post_id: second_post.id)
      topic.reload.featured_user_ids.include?(coding_horror.id).should be_false
    end

    it "won't feature the last poster" do
      Jobs::FeatureTopicUsers.new.execute(topic_id: topic.id)
      topic.reload.featured_user_ids.include?(evil_trout.id).should be_false
    end

  end

end
