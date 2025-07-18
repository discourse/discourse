# frozen_string_literal: true

require "rails_helper"

describe DiscourseZendeskPlugin::Helper do
  subject(:dummy) { Class.new { extend DiscourseZendeskPlugin::Helper } }

  it "Instantiates" do
    expect(dummy).to be_present
  end

  describe "comment_eligible_for_sync?" do
    subject(:eligible) { dummy.comment_eligible_for_sync?(post) }

    let!(:topic_user) { Fabricate(:user) }
    let!(:other_user) { Fabricate(:user) }
    let(:post_user) { topic_user }
    let!(:topic) { Fabricate(:topic, user: topic_user) }
    let!(:post) { Fabricate(:post, topic: topic, user: post_user) }
    let(:zendesk_job_push_only_author_posts) { true }

    before { SiteSetting.zendesk_job_push_only_author_posts = zendesk_job_push_only_author_posts }

    context "with zendesk_job_push_only_author_posts disabled" do
      let(:zendesk_job_push_only_author_posts) { false }

      context "with same author" do
        it "should be true" do
          expect(eligible).to be_truthy
        end
      end

      context "with different author" do
        let(:post_user) { other_user }
        it "should be true" do
          expect(eligible).to be_truthy
        end
      end
    end

    context "with zendesk_job_push_only_author_posts enabled" do
      let(:zendesk_job_push_only_author_posts) { true }

      context "with same author" do
        it "should be true" do
          expect(eligible).to be_truthy
        end
      end

      context "with different author" do
        let(:post_user) { other_user }
        it "should be false" do
          expect(eligible).to be_falsey
        end
      end
    end
  end
end
