# frozen_string_literal: true

require 'rails_helper'

describe TopicViewPostsSerializer do

  let(:user) { Fabricate(:user) }
  let(:post) { Fabricate(:post) }
  let(:topic) { post.topic }
  let!(:reviewable) { Fabricate(:reviewable_flagged_post,
    created_by: user,
    target: post,
    topic: topic,
    reviewable_scores: [
      Fabricate(:reviewable_score, reviewable_score_type: 0, status: ReviewableScore.statuses[:pending]),
      Fabricate(:reviewable_score, reviewable_score_type: 0, status: ReviewableScore.statuses[:ignored])
    ]
  )}

  it 'should return the right attributes' do
    topic_view = TopicView.new(topic, user, post_ids: [post.id])

    serializer = TopicViewPostsSerializer.new(
      topic_view,
      scope: Guardian.new(Fabricate(:admin)),
      root: false
    )

    body = JSON.parse(serializer.to_json)

    posts = body["post_stream"]["posts"]

    expect(posts.count).to eq(1)
    expect(posts.first["id"]).to eq(post.id)

    expect(posts.first["reviewable_score_count"]).to eq(2)
    expect(posts.first["reviewable_score_pending_count"]).to eq(1)

    expect(body["post_stream"]["stream"]).to eq(nil)
    expect(body["post_stream"]["timeline_lookup"]).to eq(nil)
    expect(body["post_stream"]["gaps"]).to eq(nil)

  end
end
