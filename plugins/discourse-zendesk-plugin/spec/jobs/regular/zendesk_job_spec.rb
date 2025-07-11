# frozen_string_literal: true

require "rails_helper"

RSpec.describe Jobs::ZendeskJob do
  subject(:execute) { job.execute(job_args) }

  let(:job) { described_class.new }

  let(:topic_user) { Fabricate(:user) }
  let(:other_user) { Fabricate(:user) }
  let(:post_user) { topic_user }
  let(:topic) do
    Fabricate(:topic, user: topic_user).tap do |topic|
      topic.custom_fields[::DiscourseZendeskPlugin::ZENDESK_ID_FIELD] = ticket_id
      topic.custom_fields[::DiscourseZendeskPlugin::ZENDESK_API_URL_FIELD] = ticket_url
      topic.save_custom_fields
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

  let(:job_args) { { post_id: post.id } }

  before do
    SiteSetting.zendesk_job_push_only_author_posts = zendesk_job_push_only_author_posts
    SiteSetting.zendesk_enabled = zendesk_enabled
    SiteSetting.zendesk_jobs_email = zendesk_jobs_email
    SiteSetting.zendesk_jobs_api_token = zendesk_jobs_api_token
    SiteSetting.zendesk_job_push_all_posts = zendesk_job_push_all_posts
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
    before(:each) do
      DiscourseZendeskPlugin::Helper
        .expects(:autogeneration_category?)
        .with(post.topic.category_id)
        .returns(true)
        .at_least(0)
    end

    context "with post_id" do
      before(:each) do
        Topic.expects(:find_by).never
        Post.expects(:find_by).with(id: post.id).returns(post).times(1)
        job.expects(:create_ticket).never
      end

      context "with zendesk_job_push_only_author_posts disabled" do
        it "adds the comment once" do
          job.expects(:add_comment).with(post, ticket_id).times(1)
          execute
        end

        context "when post not from topic author" do
          let(:post_user) { other_user }
          it "adds the comment once" do
            job.expects(:add_comment).with(post, ticket_id).times(1)
            execute
          end
        end
      end

      context "with zendesk_job_push_only_author_posts enabled" do
        let(:zendesk_job_push_only_author_posts) { true }

        context "with post from topic author" do
          it "adds the comment once" do
            job.expects(:add_comment).with(post, ticket_id).times(1)
            execute
          end
        end
        context "with post not from topic author" do
          let(:post_user) { other_user }
          it "does not adds the comment" do
            job.expects(:add_comment).never
            execute
          end
        end
      end
    end
  end
end
