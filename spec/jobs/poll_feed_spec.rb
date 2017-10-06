require 'rails_helper'
require_dependency 'jobs/regular/process_post'

describe Jobs::PollFeed do
  let(:poller) { Jobs::PollFeed.new }

  context "execute" do
    let(:url) { "http://eviltrout.com" }
    let(:embed_by_username) { "eviltrout" }

    before do
      $redis.del("feed-polled-recently")
    end

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

    it "won't poll if it has polled recently" do
      SiteSetting.feed_polling_enabled = true
      SiteSetting.feed_polling_url = url
      poller.expects(:poll_feed).once
      poller.execute({})
      poller.execute({})
    end

  end

  describe '#poll_feed' do
    let(:embed_by_username) { 'eviltrout' }
    let(:embed_username_key_from_feed) { 'dc_creator' }
    let!(:default_user) { Fabricate(:evil_trout) }
    let!(:feed_author) { Fabricate(:user, username: 'xrav3nz', email: 'hi@bye.com') }

    before do
      SiteSetting.feed_polling_enabled = true
      SiteSetting.feed_polling_url = 'https://blog.discourse.org/feed/'
      SiteSetting.embed_by_username = embed_by_username

      stub_request(:get, SiteSetting.feed_polling_url).to_return(
        status: 200,
        body: file_from_fixtures('feed.rss', 'feed').read,
        headers: { "Content-Type" => "application/rss+xml" }
      )
    end

    describe 'author username parsing' do
      context 'when neither embed_by_username nor embed_username_key_from_feed is set' do
        before do
          SiteSetting.embed_by_username = ""
          SiteSetting.embed_username_key_from_feed = ""
        end

        it 'does not import topics' do
          expect { poller.poll_feed }.not_to change { Topic.count }
        end
      end

      context 'when embed_by_username is set' do
        before do
          SiteSetting.embed_by_username = embed_by_username
          SiteSetting.embed_username_key_from_feed = ""
        end

        it 'creates the new topics under embed_by_username' do
          expect { poller.poll_feed }.to change { Topic.count }.by(1)
          expect(Topic.last.user).to eq(default_user)
        end
      end

      context 'when embed_username_key_from_feed is set' do
        before do
          SiteSetting.embed_username_key_from_feed = embed_username_key_from_feed
        end

        it 'creates the new topics under the username found' do
          expect { poller.poll_feed }.to change { Topic.count }.by(1)
          expect(Topic.last.user).to eq(feed_author)
        end
      end
    end

    it 'parses the title correctly' do
      expect { poller.poll_feed }.to change { Topic.count }.by(1)
      expect(Topic.last.title).to eq('Poll Feed Spec Fixture')
    end

    it 'parses the content correctly' do
      expect { poller.poll_feed }.to change { Topic.count }.by(1)
      expect(Topic.last.first_post.raw).to include('<p>This is the body &amp; content. </p>')
    end

    it 'parses the link correctly' do
      expect { poller.poll_feed }.to change { Topic.count }.by(1)
      expect(Topic.last.topic_embed.embed_url).to eq('https://blog.discourse.org/2017/09/poll-feed-spec-fixture')
    end
  end
end
