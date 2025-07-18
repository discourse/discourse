# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostCreator do
  let(:topic) { Fabricate(:post).topic }

  before { Jobs::NotifyChats.jobs.clear }

  describe "when a post is created" do
    describe "when plugin is enabled" do
      before { SiteSetting.chat_integration_enabled = true }

      it "should schedule a chat notification job" do
        freeze_time Time.now.beginning_of_day

        post = PostCreator.new(topic.user, raw: "Some post content", topic_id: topic.id).create!

        job = Jobs::NotifyChats.jobs.last

        expect(job["at"]).to eq(
          Time.now.to_f + SiteSetting.chat_integration_delay_seconds.seconds.to_f,
        )

        expect(job["args"].first["post_id"]).to eq(post.id)
      end
    end

    describe "when plugin is not enabled" do
      before { SiteSetting.chat_integration_enabled = false }

      it "should not schedule a job for chat notifications" do
        PostCreator.new(topic.user, raw: "Some post content", topic_id: topic.id).create!

        expect(Jobs::NotifyChats.jobs).to eq([])
      end
    end
  end
end
