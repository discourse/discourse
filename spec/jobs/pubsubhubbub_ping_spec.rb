require 'spec_helper'
require 'jobs/regular/pubsubhubbub_ping'

describe Jobs::PubsubhubbubPing do

  it "returns when the post cannot be found" do
    lambda { Jobs::PubsubhubbubPing.new.perform(post_id: 1, sync_exec: true) }.should_not raise_error
  end

  context 'with a topic' do

    it 'ask the pubsubhubbub hub to ping the hub with the latest topic feed' do
      post = Fabricate(:post)
      PubSubHubbubHub.expects(:ping).with(['http://test.localhost/latest.rss'])
      Jobs::PubsubhubbubPing.new.execute(topic_id: post.topic.id)
    end
  end

  context 'with a post' do

    it 'ask the pubsubhubbub hub to ping the hub with the right urls: topic, category and parent category' do
      post = Fabricate(:post)
      PubSubHubbubHub.expects(:ping).with(["http://test.localhost/t/#{post.topic.slug}/#{post.topic.id}.rss", "http://test.localhost/category/uncategorized.rss"])
      Jobs::PubsubhubbubPing.new.execute(post_id: post.id)
    end
  end
end
