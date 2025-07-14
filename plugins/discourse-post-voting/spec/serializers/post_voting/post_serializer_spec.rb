# frozen_string_literal: true

require "rails_helper"

describe PostVoting::PostSerializerExtension do
  fab!(:user)
  fab!(:topic) { Fabricate(:topic, subtype: Topic::POST_VOTING_SUBTYPE) }
  fab!(:topic_post) { Fabricate(:post, topic: topic) }
  fab!(:answer) { Fabricate(:post, topic: topic) }
  fab!(:comment) { Fabricate(:post_voting_comment, post: answer) }
  let(:topic_view) { TopicView.new(topic, user) }
  let(:up) { PostVotingVote.directions[:up] }
  let(:guardian) { Guardian.new(user) }

  let(:serialized) do
    serializer = PostSerializer.new(answer, scope: guardian, root: false)
    serializer.topic_view = topic_view
    serializer.as_json
  end

  context "with qa enabled" do
    before { SiteSetting.post_voting_enabled = true }

    it "should return the right attributes" do
      PostVoting::VoteManager.vote(answer, user, direction: up)

      expect(serialized[:post_voting_vote_count]).to eq(1)
      expect(serialized[:post_voting_user_voted_direction]).to eq(up)
      expect(serialized[:comments_count]).to eq(1)
      expect(serialized[:comments].first[:id]).to eq(comment.id)
    end
  end

  context "with qa disabled" do
    before { SiteSetting.post_voting_enabled = false }

    it "should not include dependent_keys" do
      expect(serialized[:qa_vote_count]).to eq(nil)
      expect(serialized[:qa_user_voted_direction]).to eq(nil)
      expect(serialized[:comments_count]).to eq(nil)
      expect(serialized[:comments]).to eq(nil)
    end
  end
end
