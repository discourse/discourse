require 'rails_helper'
require_dependency 'jobs/regular/process_post'

describe Jobs::PollFeed do
  let(:poller) { Jobs::PollFeed.new }

  context "execute" do
    let(:url) { "http://eviltrout.com" }
    let(:embed_by_username) { "eviltrout" }

    it "requires feed_polling_enabled?" do
        SiteSetting.feed_polling_enabled = true
        SiteSetting.feed_polling_url = nil
        poller.expects(:poll_feed).never
        poller.execute({})
    end

    it "requires feed_polling_url" do
        SiteSetting.feed_polling_enabled = false
        SiteSetting.feed_polling_url = nil
        poller.expects(:poll_feed).never
        poller.execute({})
    end

    it "delegates to poll_feed" do
      SiteSetting.feed_polling_enabled = true
      SiteSetting.feed_polling_url = url
      poller.expects(:poll_feed).once
      poller.execute({})
    end
  end

end
