require 'spec_helper'
require_dependency 'post_destroyer'

describe FeedObserver do

  before do
    ActiveRecord::Base.observers.enable :feed_observer
    PubSubHubbubHub.stubs(:ping)
  end

  let(:user) { Fabricate(:user) }
  let(:topic) { create_topic(title: "Who needs a mother when you have the NSA") }


  context 'when creating a new topic' do
    it 'ask the pubsubhubbub hub to ping the hub' do
      PubSubHubbubHub.expects(:ping).with(['http://test.localhost/latest.rss'])
      create_topic(title: "Who needs a mother when you have the NSA")
    end
  end

  context 'when creating a new post' do
    it 'ask the pubsubhubbub hub to ping the hub with the right urls: filters, topic, category and parent category' do
      PubSubHubbubHub.expects(:ping).with(["http://test.localhost/latest.rss", "http://test.localhost/t/#{topic.slug}/#{topic.id}.rss", "http://test.localhost/category/uncategorized.rss"])
      Fabricate(:post, user: user, raw: 'second post', topic: topic)
    end
  end
end
