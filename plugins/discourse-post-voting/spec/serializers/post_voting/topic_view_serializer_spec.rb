# frozen_string_literal: true

require "rails_helper"

describe PostVoting::TopicViewSerializerExtension do
  fab!(:topic) { Fabricate(:topic, subtype: Topic::POST_VOTING_SUBTYPE) }
  fab!(:topic_post) { Fabricate(:post, topic: topic) }
  fab!(:answer) { Fabricate(:post, topic: topic, reply_to_post_number: nil) }
  fab!(:comment) { Fabricate(:post_voting_comment, post: answer) }
  fab!(:user)
  fab!(:guardian) { Guardian.new(user) }
  let(:topic_view) { TopicView.new(topic, user) }

  before { SiteSetting.post_voting_enabled = true }

  it "should return correct values" do
    PostVoting::VoteManager.vote(topic_post, user)
    PostVoting::VoteManager.vote(answer, user)
    PostVoting::VoteManager.vote(answer, Fabricate(:user))
    PostVoting::VoteManager.vote(comment, user)

    payload = TopicViewSerializer.new(topic_view, scope: guardian, root: false).as_json

    expect(payload[:last_answered_at]).to eq(answer.created_at)
    expect(payload[:last_commented_on]).to eq(comment.created_at)
    expect(payload[:answer_count]).to eq(1)
    expect(payload[:last_answer_post_number]).to eq(answer.post_number)
    expect(payload[:last_answerer][:id]).to eq(answer.user.id)

    posts = payload[:post_stream][:posts]

    expect(posts.first[:id]).to eq(topic_post.id)
    expect(posts.first[:post_voting_user_voted_direction]).to eq(PostVotingVote.directions[:up])
    expect(posts.first[:post_voting_has_votes]).to eq(true)
    expect(posts.first[:post_voting_vote_count]).to eq(1)
    expect(posts.first[:comments]).to eq([])
    expect(posts.first[:comments_count]).to eq(0)

    expect(posts.last[:id]).to eq(answer.id)
    expect(posts.last[:post_voting_user_voted_direction]).to eq(PostVotingVote.directions[:up])
    expect(posts.last[:post_voting_has_votes]).to eq(true)
    expect(posts.last[:post_voting_vote_count]).to eq(2)
    expect(posts.last[:comments].map { |c| c[:id] }).to contain_exactly(comment.id)
    expect(posts.last[:comments].first[:user_voted]).to eq(true)
    expect(posts.last[:comments_count]).to eq(1)
  end

  it "should not include dependent_attrs when plugin is disabled" do
    SiteSetting.post_voting_enabled = false

    payload = TopicViewSerializer.new(topic_view, scope: guardian, root: false).as_json

    expect(payload[:post_voting_enabled]).to eq(nil)
    expect(payload[:last_answered_at]).to eq(nil)
    expect(payload[:last_commented_on]).to eq(nil)
    expect(payload[:answer_count]).to eq(nil)
    expect(payload[:last_answer_post_number]).to eq(nil)
    expect(payload[:last_answerer]).to eq(nil)
  end
end
