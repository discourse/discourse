require 'rails_helper'

RSpec.describe TopicViewPostsSerializer do
  let(:user) { Fabricate(:user) }
  let(:post) { Fabricate(:post) }
  let(:topic) { post.topic }
  let(:topic_view) { TopicView.new(topic, user, post_ids: [post.id]) }

  subject do
    described_class.new(topic_view,
      scope: Guardian.new(Fabricate(:admin)),
      root: false
    )
  end

  it 'should return the right attributes' do
    body = JSON.parse(subject.to_json)

    posts = body["post_stream"]["posts"]

    expect(posts.count).to eq(1)
    expect(posts.first["id"]).to eq(post.id)
    expect(body["post_stream"]["stream"]).to eq(nil)
    expect(body["post_stream"]["timeline_lookup"]).to eq(nil)
    expect(body["post_stream"]["gaps"]).to eq(nil)
  end
end
