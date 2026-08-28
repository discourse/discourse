# frozen_string_literal: true

RSpec.describe Jobs::ZendeskJob do
  subject(:execute) { job.execute(job_args) }

  let(:job) { described_class.new }

  let(:topic_user) { Fabricate(:user) }
  let(:other_user) { Fabricate(:user) }
  let(:post_user) { topic_user }
  let(:category) { Fabricate(:category) }
  let(:topic) do
    Fabricate(:topic, user: topic_user, category: category).tap do |topic|
      if ticket_id.present?
        topic.custom_fields[DiscourseZendeskPlugin::ZENDESK_ID_FIELD] = ticket_id
        topic.custom_fields[DiscourseZendeskPlugin::ZENDESK_API_URL_FIELD] = ticket_url
        topic.save_custom_fields
      end
    end
  end
  let(:ticket_id) { "1234" }
  let(:ticket_url) { "http://example.com/ticket/#{ticket_id}" }
  let(:post) { Fabricate(:post, topic: topic, user: post_user, post_number: 2) }
  let(:zendesk_job_push_only_author_posts) { false }
  let(:zendesk_job_push_all_posts) { true }
  let(:zendesk_enabled) { false }
  let(:zendesk_jobs_email) { "test@example.com" }
  let(:zendesk_jobs_api_token) { "1234567890" }
  let(:zendesk_autogenerate_all_categories) { false }

  let(:job_args) { { post_id: post.id } }

  before do
    SiteSetting.zendesk_job_push_only_author_posts = zendesk_job_push_only_author_posts
    SiteSetting.zendesk_enabled = zendesk_enabled
    SiteSetting.zendesk_jobs_email = zendesk_jobs_email
    SiteSetting.zendesk_jobs_api_token = zendesk_jobs_api_token
    SiteSetting.zendesk_job_push_all_posts = zendesk_job_push_all_posts
    SiteSetting.zendesk_autogenerate_all_categories = zendesk_autogenerate_all_categories
  end

  describe ".sidekiq_retry_in_block" do
    subject(:retry_strategy) do
      described_class.sidekiq_retry_in_block.call(0, Jobs::HandledExceptionWrapper.new(error))
    end

    context "with a permanent OAuth configuration error" do
      let(:error) do
        DiscourseZendeskPlugin::OAuthToken::PermanentRequestError.new(
          "Zendesk OAuth token request failed",
        )
      end

      it "discards the job" do
        expect(retry_strategy).to eq(:discard)
      end
    end

    context "with a transient OAuth request error" do
      let(:error) do
        DiscourseZendeskPlugin::OAuthToken::RequestError.new("Zendesk OAuth token request failed")
      end

      it "uses the default retry strategy" do
        expect(retry_strategy).to be_nil
      end
    end
  end

  context "with zendesk disabled" do
    it "does nothing" do
      Topic.expects(:find_by).never
      Post.expects(:find_by).never
      execute
    end
  end

  context "with zendesk enabled" do
    let(:zendesk_enabled) { true }

    context "when topic has existing zendesk ticket" do
      let(:ticket_id) { "1234" }

      context "when category is NOT in autogenerate list" do
        before do
          Post.expects(:find_by).with(id: post.id).returns(post).once
          job.expects(:create_ticket).never
        end

        context "with zendesk_job_push_only_author_posts disabled" do
          it "adds the comment" do
            job.expects(:add_comment).with(post, ticket_id).once
            execute
          end

          context "when post not from topic author" do
            let(:post_user) { other_user }

            it "adds the comment" do
              job.expects(:add_comment).with(post, ticket_id).once
              execute
            end
          end
        end

        context "with zendesk_job_push_only_author_posts enabled" do
          let(:zendesk_job_push_only_author_posts) { true }

          context "with post from topic author" do
            it "adds the comment" do
              job.expects(:add_comment).with(post, ticket_id).once
              execute
            end
          end

          context "with post not from topic author" do
            let(:post_user) { other_user }

            it "does not add the comment" do
              job.expects(:add_comment).never
              execute
            end
          end
        end
      end

      context "when category is in autogenerate list" do
        let(:zendesk_autogenerate_all_categories) { true }

        before do
          Post.expects(:find_by).with(id: post.id).returns(post).once
          job.expects(:create_ticket).never
        end

        it "adds the comment" do
          job.expects(:add_comment).with(post, ticket_id).once
          execute
        end
      end
    end

    context "when topic does NOT have existing zendesk ticket" do
      let(:ticket_id) { nil }
      let(:post) { Fabricate(:post, topic: topic, user: post_user, post_number: 1) }

      context "when category is NOT in autogenerate list" do
        before { Post.expects(:find_by).with(id: post.id).returns(post).once }

        it "does not create a ticket" do
          job.expects(:create_ticket).never
          job.expects(:add_comment).never
          execute
        end
      end

      context "when category is in autogenerate list" do
        let(:zendesk_autogenerate_all_categories) { true }

        before { Post.expects(:find_by).with(id: post.id).returns(post).once }

        it "creates a ticket" do
          job.expects(:create_ticket).with(post).once
          job.expects(:add_comment).never
          execute
        end
      end
    end

    context "when zendesk_job_push_all_posts is disabled" do
      let(:zendesk_job_push_all_posts) { false }
      let(:zendesk_autogenerate_all_categories) { true }

      context "with first post" do
        let(:post) { Fabricate(:post, topic: topic, user: post_user, post_number: 1) }
        let(:ticket_id) { nil }

        before { Post.expects(:find_by).with(id: post.id).returns(post).once }

        it "creates a ticket" do
          job.expects(:create_ticket).with(post).once
          execute
        end
      end

      context "with reply post" do
        let(:post) { Fabricate(:post, topic: topic, user: post_user, post_number: 2) }

        before { Post.expects(:find_by).with(id: post.id).returns(post).once }

        it "does not process the post" do
          job.expects(:create_ticket).never
          job.expects(:add_comment).never
          execute
        end
      end
    end
  end

  describe "#execute" do
    context "when only OAuth credentials are configured" do
      let(:zendesk_enabled) { true }
      let(:zendesk_jobs_email) { "" }
      let(:zendesk_jobs_api_token) { "" }
      let(:zendesk_api_url) { "https://your-url.zendesk.com/api/v2" }
      let(:zendesk_comment_request) do
        stub_request(:put, "#{zendesk_api_url}/tickets/#{ticket_id}").with(
          headers: {
            "Authorization" => "Bearer oauth-access-token",
          },
        ).to_return(
          status: 200,
          body: {
            ticket: {
              id: ticket_id,
            },
            audit: {
              events: [{ id: "comment-id", type: "Comment" }],
            },
          }.to_json,
          headers: {
            "Content-Type" => "application/json",
          },
        )
      end

      before do
        SiteSetting.zendesk_oauth_client_id = "oauth-client-id"
        SiteSetting.zendesk_oauth_client_secret = "oauth-client-secret"
        stub_request(:post, "https://your-url.zendesk.com/oauth/tokens").to_return(
          status: 200,
          body: { access_token: "oauth-access-token", expires_in: 1800 }.to_json,
        )
        stub_request(:get, "#{zendesk_api_url}/users/search?query=#{post.user.email}").to_return(
          status: 200,
          body: { users: [{ id: "zendesk-user-id" }] }.to_json,
          headers: {
            "Content-Type" => "application/json",
          },
        )
        zendesk_comment_request
      end

      it "pushes the post with OAuth authentication" do
        execute

        expect(zendesk_comment_request).to have_been_requested.once
        expect(post.reload.custom_fields[DiscourseZendeskPlugin::ZENDESK_ID_FIELD]).to eq(
          "comment-id",
        )
        expect(WebMock).not_to have_requested(:get, %r{/tickets/.*/comments})
      end
    end
  end
end
