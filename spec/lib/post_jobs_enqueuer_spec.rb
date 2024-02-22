# frozen_string_literal: true

RSpec.describe PostJobsEnqueuer do
  subject(:enqueuer) { described_class.new(post, topic, new_topic, opts) }

  let!(:post) { Fabricate(:post, topic: topic) }
  let!(:topic) { Fabricate(:topic) }
  let(:new_topic) { false }
  let(:opts) { { post_alert_options: {} } }

  context "for regular topics" do
    it "enqueues the :post_alert job" do
      expect_enqueued_with(
        job: :post_alert,
        args: {
          post_id: post.id,
          new_record: true,
          options: opts[:post_alert_options],
        },
      ) { enqueuer.enqueue_jobs }
    end

    it "enqueues the :notify_mailing_list_subscribers job" do
      expect_enqueued_with(job: :notify_mailing_list_subscribers, args: { post_id: post.id }) do
        enqueuer.enqueue_jobs
      end
    end

    it "enqueues the :post_update_topic_tracking_state job" do
      expect_enqueued_with(job: :post_update_topic_tracking_state, args: { post_id: post.id }) do
        enqueuer.enqueue_jobs
      end
    end

    it "enqueues the :feature_topic_users job" do
      expect_enqueued_with(job: :feature_topic_users, args: { topic_id: topic.id }) do
        enqueuer.enqueue_jobs
      end
    end

    context "for new topics" do
      let(:new_topic) { true }

      it "calls the correct topic tracking state class to publish_new" do
        TopicTrackingState.expects(:publish_new).with(topic)
        PrivateMessageTopicTrackingState.expects(:publish_new).never
        enqueuer.enqueue_jobs
      end
    end
  end

  context "for private messages" do
    let!(:topic) { Fabricate(:private_message_topic) }

    it "does not enqueue the :notify_mailing_list_subscribers job" do
      expect_not_enqueued_with(job: :notify_mailing_list_subscribers, args: { post_id: post.id }) do
        enqueuer.enqueue_jobs
      end
    end

    it "enqueues the :post_update_topic_tracking_state job" do
      expect_enqueued_with(job: :post_update_topic_tracking_state, args: { post_id: post.id }) do
        enqueuer.enqueue_jobs
      end
    end

    it "enqueues the :feature_topic_users job" do
      expect_enqueued_with(job: :feature_topic_users, args: { topic_id: topic.id }) do
        enqueuer.enqueue_jobs
      end
    end

    context "for new topics" do
      let(:new_topic) { true }

      it "calls the correct topic tracking state class to publish_new" do
        TopicTrackingState.expects(:publish_new).never
        PrivateMessageTopicTrackingState.expects(:publish_new).with(topic)
        enqueuer.enqueue_jobs
      end
    end

    context "for a post > post_number 1" do
      let!(:post) do
        Fabricate(:post, topic: topic)
        Fabricate(:post, topic: topic)
      end

      context "when there is a topic embed" do
        before do
          SiteSetting.embed_unlisted = true
          topic.update(visible: false)
          Fabricate(:topic_embed, post: post, embed_url: "http://test.com")
        end

        it "does not enqueue the :make_embedded_topic_visible job" do
          expect_not_enqueued_with(
            job: :make_embedded_topic_visible,
            args: {
              topic_id: topic.id,
            },
          ) { enqueuer.enqueue_jobs }
        end
      end
    end
  end
end
