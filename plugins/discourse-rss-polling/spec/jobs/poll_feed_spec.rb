# frozen_string_literal: true

RSpec.describe Jobs::DiscourseRssPolling::PollFeed do
  subject(:job) { described_class.new }

  let(:feed_url) { "https://blog.discourse.org/feed/" }
  let(:author) { Fabricate(:user, trust_level: 1) }
  let(:raw_feed) { file_from_fixtures("feed.rss", "feed") }

  before { SiteSetting.rss_polling_enabled = true }

  describe "#execute" do
    before do
      Discourse.redis.del("rss-polling-feed-polled:#{Digest::SHA1.hexdigest(feed_url)}")
      stub_request(:get, feed_url).to_return(status: 200, body: raw_feed)
    end

    it "creates a topic with the right title, content and author" do
      expect { job.execute(feed_url: feed_url, author_username: author.username) }.to change {
        author.topics.count
      }

      topic = author.topics.last

      expect(topic.title).to eq("Poll Feed Spec Fixture")
      expect(topic.first_post.raw).to include("<p>This is the body &amp; content. </p>")
      expect(topic.topic_embed.embed_url).to eq(
        "https://blog.discourse.org/2017/09/poll-feed-spec-fixture",
      )
    end

    context "with use_pubdate set to false" do
      before do
        SiteSetting.rss_polling_use_pubdate = false
        job.execute(feed_url: feed_url, author_username: author.username)
      end

      it "has a publication date of now" do
        topic = author.topics.last
        expect(topic.created_at.utc).to be_within(1.second).of Time.now
        expect(topic.first_post.created_at.utc).to be_within(1.second).of Time.now
      end
    end

    context "with use_pubdate set to true" do
      before do
        SiteSetting.rss_polling_use_pubdate = true
        job.execute(feed_url: feed_url, author_username: author.username)
      end

      it "has a publication date of the feed" do
        topic = author.topics.last
        expect(topic.created_at).to eq_time(DateTime.parse("2017-09-14 15:22:33.000000000 +0000"))
        expect(topic.first_post.created_at).to eq_time(
          DateTime.parse("2017-09-14 15:22:33.000000000 +0000"),
        )
      end
    end

    context "with a previous poll on a topic with tags" do
      let(:tag1) { Fabricate(:tag, name: "test-from-rss") }
      let(:tag2) { Fabricate(:tag, name: "test-update-from-rss") }

      before do
        SiteSetting.tagging_enabled = true
        job.execute(
          feed_url: feed_url,
          author_username: author.username,
          discourse_tags: [tag1.name],
        )
        Discourse.redis.del("rss-polling-feed-polled:#{Digest::SHA1.hexdigest(feed_url)}")
      end

      context "with rss polling set to true" do
        before { SiteSetting.rss_polling_update_tags = true }
        it "updates tags by default" do
          topic = author.topics.last
          job.execute(
            feed_url: feed_url,
            author_username: author.username,
            discourse_tags: [tag2.name],
          )
          topic = author.topics.last.reload
          expect(topic.tags).to match_array([tag2])
        end
      end

      context "with rss polling set to false" do
        before { SiteSetting.rss_polling_update_tags = false }

        it "does not update tags" do
          job.execute(
            feed_url: feed_url,
            author_username: author.username,
            discourse_tags: [tag2.name],
          )
          topic = author.topics.last
          expect(topic.tags).to match_array([tag1])
        end
      end
    end

    it "is rate limited by rss_polling_frequency" do
      2.times { job.execute(feed_url: feed_url, author_username: author.username) }

      expect(WebMock).to have_requested(:get, feed_url).once
    end

    it "is not raising error if http request failed" do
      stub_request(:get, feed_url).to_return(status: 500)
      job.execute(feed_url: feed_url, author_username: author.username)
    end

    it "skips the topic if the category doesn't exist on our side" do
      invalid_discourse_category_id = 99

      expect {
        job.execute(
          feed_url: feed_url,
          author_username: author.username,
          discourse_category_id: invalid_discourse_category_id,
        )
      }.not_to change { author.topics.count }

      expect(author.topics.last).to be_nil
    end

    it "does not raise error for valid xml but non-rss content" do
      stub_request(:get, feed_url).to_return(status: 200, body: "<html><body>tesing</body></html>")

      expect {
        job.execute(feed_url: feed_url, author_username: author.username)
      }.not_to raise_error
    end

    it "does not raise error for valid xml but non-rss title" do
      stub_request(:get, feed_url).to_return(
        status: 200,
        body: rss_polling_file_fixture("mastodon.rss").read,
      )

      expect {
        job.execute(feed_url: feed_url, author_username: author.username)
      }.not_to raise_error
    end

    it "sends API credentials as headers instead of query parameters" do
      authenticated_url = "#{feed_url}?api_key=test123&api_username=testuser"

      Discourse.redis.del("rss-polling-feed-polled:#{Digest::SHA1.hexdigest(authenticated_url)}")

      stub_request(:get, feed_url).with(
        headers: {
          "Api-Key" => "test123",
          "Api-Username" => "testuser",
        },
      ).to_return(status: 200, body: file_from_fixtures("feed.rss", "feed"))

      expect {
        job.execute(feed_url: authenticated_url, author_username: author.username)
      }.to change { author.topics.count }.by(1)
    end

    context "with user_id" do
      it "creates a topic when given user_id" do
        expect { job.execute(feed_url: feed_url, user_id: author.id) }.to change {
          author.topics.count
        }.by(1)
      end

      it "keeps working after the user is renamed" do
        UsernameChanger.change(author, "renamed_account")

        expect { job.execute(feed_url: feed_url, user_id: author.id) }.to change {
          author.reload.topics.count
        }.by(1)
      end

      it "falls back to the system user and logs when the referenced user no longer exists" do
        deleted_id = author.id
        author.destroy!

        Rails.logger.expects(:warn).with(includes("not found")).at_least_once

        expect { job.execute(feed_url: feed_url, user_id: deleted_id) }.to change {
          Discourse.system_user.topics.count
        }.by(1)
      end
    end

    context "with an unknown author_username (legacy fallback)" do
      it "falls back to the system user and logs a warning" do
        Rails.logger.expects(:warn).with(includes("not found")).at_least_once

        expect { job.execute(feed_url: feed_url, author_username: "ghost_user") }.to change {
          Discourse.system_user.topics.count
        }.by(1)
      end
    end

    context "with an rss_feed_id" do
      let(:rss_feed) { Fabricate(:rss_feed, url: feed_url, user: author) }

      it "records a poll attempt with per-item outcomes" do
        expect {
          job.execute(feed_url: feed_url, user_id: author.id, rss_feed_id: rss_feed.id)
        }.to change { DiscourseRssPolling::PollAttempt.count }.by(1)

        attempt = DiscourseRssPolling::PollAttempt.last
        expect(attempt.rss_feed_id).to eq(rss_feed.id)
        expect(attempt.status).to eq("success")
        expect(attempt.imported_count).to eq(1)
        expect(attempt.items.first).to include(
          "status" => "imported",
          "title" => "Poll Feed Spec Fixture",
        )
        expect(attempt.items.first["topic_url"]).to be_present
      end

      it "publishes the recorded attempt to the admin-only message bus channel" do
        messages =
          MessageBus.track_publish("/rss-polling/feeds/#{rss_feed.id}") do
            job.execute(feed_url: feed_url, user_id: author.id, rss_feed_id: rss_feed.id)
          end

        expect(messages.size).to eq(1)
        expect(messages.first.group_ids).to eq([Group::AUTO_GROUPS[:admins]])
        expect(messages.first.data[:status]).to eq("success")
        expect(messages.first.data[:imported_count]).to eq(1)
      end

      it "polls again when force is true even if it was polled recently" do
        job.execute(feed_url: feed_url, user_id: author.id, rss_feed_id: rss_feed.id)
        expect(DiscourseRssPolling::PollAttempt.count).to eq(1)

        job.execute(feed_url: feed_url, user_id: author.id, rss_feed_id: rss_feed.id)
        expect(DiscourseRssPolling::PollAttempt.count).to eq(1)

        job.execute(feed_url: feed_url, user_id: author.id, rss_feed_id: rss_feed.id, force: true)
        expect(DiscourseRssPolling::PollAttempt.count).to eq(2)
      end

      it "marks the feed as recently polled when forced so the next scheduled poll is throttled" do
        job.execute(feed_url: feed_url, user_id: author.id, rss_feed_id: rss_feed.id, force: true)
        expect(DiscourseRssPolling::PollAttempt.count).to eq(1)

        job.execute(feed_url: feed_url, user_id: author.id, rss_feed_id: rss_feed.id)
        expect(DiscourseRssPolling::PollAttempt.count).to eq(1)
      end

      it "does not poll a disabled feed on a scheduled (non-forced) run" do
        rss_feed.update!(enabled: false)

        expect {
          job.execute(feed_url: feed_url, user_id: author.id, rss_feed_id: rss_feed.id)
        }.not_to change { DiscourseRssPolling::PollAttempt.count }
      end

      it "does not poll a disabled feed even when forced" do
        rss_feed.update!(enabled: false)

        expect {
          job.execute(feed_url: feed_url, user_id: author.id, rss_feed_id: rss_feed.id, force: true)
        }.not_to change { DiscourseRssPolling::PollAttempt.count }
      end

      it "records a skipped outcome when the category filter doesn't match" do
        job.execute(
          feed_url: feed_url,
          user_id: author.id,
          rss_feed_id: rss_feed.id,
          feed_category_filter: "does-not-match",
        )

        attempt = DiscourseRssPolling::PollAttempt.last
        expect(attempt.skipped_count).to eq(1)
        expect(attempt.items.first).to include(
          "status" => "skipped",
          "reason" => "category_filter_mismatch",
        )
      end

      it "records a failed outcome with a reason when an item can't be imported" do
        TopicEmbed.stubs(:import).returns(nil)

        job.execute(feed_url: feed_url, user_id: author.id, rss_feed_id: rss_feed.id)

        attempt = DiscourseRssPolling::PollAttempt.last
        expect(attempt.status).to eq("error")
        expect(attempt.failed_count).to eq(1)
        expect(attempt.imported_count).to eq(0)
        expect(attempt.items.first).to include("status" => "failed", "reason" => "import_rejected")
      end

      it "isolates a failing item, records its error message, and keeps polling" do
        TopicEmbed.stubs(:import).raises(StandardError.new("boom"))

        expect {
          job.execute(feed_url: feed_url, user_id: author.id, rss_feed_id: rss_feed.id)
        }.not_to raise_error

        attempt = DiscourseRssPolling::PollAttempt.last
        expect(attempt.status).to eq("error")
        expect(attempt.failed_count).to eq(1)
        expect(attempt.items.first["status"]).to eq("failed")
        expect(attempt.items.first["reason"]).to include("boom")
      end

      it "records an error attempt and re-raises when the whole poll fails" do
        DiscourseRssPolling::RssFeed::Action::FetchFeed.stubs(:call).raises(
          StandardError.new("kaboom"),
        )

        expect {
          job.execute(feed_url: feed_url, user_id: author.id, rss_feed_id: rss_feed.id)
        }.to raise_error(StandardError)

        attempt = DiscourseRssPolling::PollAttempt.last
        expect(attempt).to be_present
        expect(attempt.status).to eq("error")
        expect(attempt.error).to eq("unknown")
      end

      it "records a breadcrumb attempt when the target category was deleted" do
        category = Fabricate(:category)
        deleted_id = category.id
        category.destroy!

        expect {
          job.execute(
            feed_url: feed_url,
            user_id: author.id,
            rss_feed_id: rss_feed.id,
            discourse_category_id: deleted_id,
          )
        }.to change { DiscourseRssPolling::PollAttempt.count }.by(1)

        attempt = DiscourseRssPolling::PollAttempt.last
        expect(attempt.status).to eq("error")
        expect(attempt.error).to eq("category_deleted")
        expect(attempt.items).to be_empty
      end

      it "does not record duplicate category_deleted breadcrumbs on repeated scheduled polls" do
        category = Fabricate(:category)
        deleted_id = category.id
        category.destroy!

        2.times do
          job.execute(
            feed_url: feed_url,
            user_id: author.id,
            rss_feed_id: rss_feed.id,
            discourse_category_id: deleted_id,
          )
        end

        expect(
          DiscourseRssPolling::PollAttempt.where(
            rss_feed_id: rss_feed.id,
            error: "category_deleted",
          ).count,
        ).to eq(1)
      end

      it "resumes polling once the category is restored (throttle not consumed by the breadcrumb)" do
        category = Fabricate(:category)
        deleted_id = category.id
        category.destroy!

        job.execute(
          feed_url: feed_url,
          user_id: author.id,
          rss_feed_id: rss_feed.id,
          discourse_category_id: deleted_id,
        )

        new_category = Fabricate(:category)

        expect {
          job.execute(
            feed_url: feed_url,
            user_id: author.id,
            rss_feed_id: rss_feed.id,
            discourse_category_id: new_category.id,
          )
        }.to change { author.topics.count }.by(1)
      end

      it "keeps only the most recent attempts per feed" do
        stub_const(DiscourseRssPolling::PollAttempt, "KEEP_PER_FEED", 2) do
          4.times { DiscourseRssPolling::PollAttempt.record!(rss_feed_id: rss_feed.id, items: []) }
        end

        expect(DiscourseRssPolling::PollAttempt.where(rss_feed_id: rss_feed.id).count).to eq(2)
      end
    end
  end
end
