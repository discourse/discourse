# frozen_string_literal: true

RSpec.describe DiscourseAi::Summarization::SummaryController do
  describe "#summary" do
    fab!(:topic) { Fabricate(:topic, highest_post_number: 2) }
    fab!(:post_1) { Fabricate(:post, topic: topic, post_number: 1) }
    fab!(:post_2) { Fabricate(:post, topic: topic, post_number: 2) }

    before do
      enable_current_plugin
      assign_fake_provider_to(:ai_default_llm_model)
      SiteSetting.ai_summarization_enabled = true
    end

    context "when streaming" do
      it "return a cached summary with json payload and does not trigger job if it exists" do
        summary = Fabricate(:ai_summary, target: topic)
        sign_in(Fabricate(:admin))

        get "/discourse-ai/summarization/t/#{topic.id}.json?stream=true"

        expect(response.status).to eq(200)
        expect(Jobs::StreamTopicAiSummary.jobs.size).to eq(0)

        response_summary = response.parsed_body
        expect(response_summary.dig("ai_topic_summary", "summarized_text")).to eq(
          summary.summarized_text,
        )
      end
    end

    context "for anons" do
      it "returns a 404 if there is no cached summary" do
        get "/discourse-ai/summarization/t/#{topic.id}.json"

        expect(response.status).to eq(404)
      end

      it "returns a cached summary" do
        summary = Fabricate(:ai_summary, target: topic)
        get "/discourse-ai/summarization/t/#{topic.id}.json"

        expect(response.status).to eq(200)

        response_summary = response.parsed_body
        expect(response_summary.dig("ai_topic_summary", "summarized_text")).to eq(
          summary.summarized_text,
        )
      end
    end

    context "when the user is a member of an allowlisted group" do
      fab!(:user, :leader)

      before do
        sign_in(user)
        Group.find(Group::AUTO_GROUPS[:trust_level_3]).add(user)
      end

      it "returns a 404 if there is no topic" do
        invalid_topic_id = 999

        get "/discourse-ai/summarization/t/#{invalid_topic_id}.json"

        expect(response.status).to eq(404)
      end

      it "returns a 403 if not allowed to see the topic" do
        pm = Fabricate(:private_message_topic)

        get "/discourse-ai/summarization/t/#{pm.id}.json"

        expect(response.status).to eq(403)
      end

      it "returns a summary" do
        summary_text = "This is a summary"

        DiscourseAi::Completions::Llm.with_prepared_responses([summary_text]) do
          get "/discourse-ai/summarization/t/#{topic.id}.json"

          expect(response.status).to eq(200)
          response_summary = response.parsed_body["ai_topic_summary"]
          summary = AiSummary.last

          expect(summary.summarized_text).to eq(summary_text)
          expect(response_summary["summarized_text"]).to eq(summary.summarized_text)
          expect(response_summary["algorithm"]).to eq("fake")
          expect(response_summary["outdated"]).to eq(false)
          expect(response_summary["can_regenerate"]).to eq(true)
          expect(response_summary["new_posts_since_summary"]).to be_zero
        end
      end

      it "signals the summary is outdated" do
        get "/discourse-ai/summarization/t/#{topic.id}.json"

        Fabricate(:post, topic: topic, post_number: 3)
        topic.update!(highest_post_number: 3)

        get "/discourse-ai/summarization/t/#{topic.id}.json"
        expect(response.status).to eq(200)
        summary = response.parsed_body["ai_topic_summary"]

        expect(summary["outdated"]).to eq(true)
        expect(summary["new_posts_since_summary"]).to eq(1)
      end
    end

    context "when the user is not a member of an allowlisted group" do
      fab!(:user)

      before { sign_in(user) }

      it "return a 404 if there is no cached summary" do
        get "/discourse-ai/summarization/t/#{topic.id}.json"

        expect(response.status).to eq(404)
      end

      it "returns a cached summary" do
        summary = Fabricate(:ai_summary, target: topic)

        get "/discourse-ai/summarization/t/#{topic.id}.json"

        expect(response.status).to eq(200)

        response_summary = response.parsed_body
        expect(response_summary.dig("ai_topic_summary", "summarized_text")).to eq(
          summary.summarized_text,
        )
      end
    end
  end

  describe "#regen_gist" do
    fab!(:admin)
    fab!(:group)
    fab!(:topic)
    fab!(:post_1) { Fabricate(:post, topic: topic, post_number: 1) }
    fab!(:post_2) { Fabricate(:post, topic: topic, post_number: 2) }

    fab!(:topic_1, :topic)
    fab!(:post_3) { Fabricate(:post, topic: topic_1, post_number: 1) }
    fab!(:post_4) { Fabricate(:post, topic: topic_1, post_number: 2) }

    before do
      enable_current_plugin
      assign_fake_provider_to(:ai_default_llm_model)
      SiteSetting.ai_summarization_enabled = true
      SiteSetting.ai_summary_gists_enabled = true

      group.add(admin)
      assign_persona_to(:ai_summary_gists_persona, [group.id])
      Jobs.run_immediately!
    end

    context "when a single topic id is provided" do
      before { sign_in(admin) }

      it "regenerates the gist" do
        put "/discourse-ai/summarization/regen_gist", params: { topic_id: topic.id }

        expect(response.status).to eq(200)
        expect(AiSummary.gist.where(target: topic).count).to eq(1)
      end
    end

    context "when multiple topic ids are provided" do
      before { sign_in(admin) }

      it "regenerates the gists" do
        put "/discourse-ai/summarization/regen_gist", params: { topic_ids: [topic.id, topic_1.id] }

        expect(response.status).to eq(200)
        expect(AiSummary.gist.where(target: topic).count).to eq(1)
        expect(AiSummary.gist.where(target: topic_1).count).to eq(1)
      end
    end

    context "when more than 30 topics are provided" do
      before { sign_in(admin) }

      it "raises an error" do
        topics = 31.times.map { Fabricate(:topic) }
        topic_ids = topics.map(&:id)

        put "/discourse-ai/summarization/regen_gist", params: { topic_ids: topic_ids }

        expect(response.status).to eq(400)
      end
    end

    context "when user is not allowed to regenerate gists" do
      fab!(:user)

      before { sign_in(user) }

      it "returns a 403" do
        put "/discourse-ai/summarization/regen_gist", params: { topic_id: topic.id }

        expect(response.status).to eq(403)
      end
    end
  end

  describe "#regen_summary" do
    fab!(:admin)
    fab!(:group)
    fab!(:topic)
    fab!(:post_1) { Fabricate(:post, topic: topic, post_number: 1) }
    fab!(:post_2) { Fabricate(:post, topic: topic, post_number: 2) }

    fab!(:topic_1, :topic)
    fab!(:post_3) { Fabricate(:post, topic: topic_1, post_number: 1) }
    fab!(:post_4) { Fabricate(:post, topic: topic_1, post_number: 2) }

    before do
      enable_current_plugin
      assign_fake_provider_to(:ai_default_llm_model)
      SiteSetting.ai_summarization_enabled = true

      group.add(admin)
      assign_persona_to(:ai_summarization_persona, [group.id])
    end

    context "when a single topic id is provided" do
      before { sign_in(admin) }

      it "deletes cached summary and enqueues regeneration job" do
        existing_summary = Fabricate(:ai_summary, target: topic)

        put "/discourse-ai/summarization/regen_summary", params: { topic_id: topic.id }

        expect(response.status).to eq(200)
        expect(AiSummary.find_by(id: existing_summary.id)).to be_nil
        expect(Jobs::StreamTopicAiSummary.jobs.size).to eq(1)

        job_args = Jobs::StreamTopicAiSummary.jobs.first["args"].first
        expect(job_args["topic_id"]).to eq(topic.id)
        expect(job_args["user_id"]).to eq(admin.id)
        expect(job_args["skip_age_check"]).to eq(true)
      end

      it "enqueues job even when there is no existing summary" do
        put "/discourse-ai/summarization/regen_summary", params: { topic_id: topic.id }

        expect(response.status).to eq(200)
        expect(Jobs::StreamTopicAiSummary.jobs.size).to eq(1)
      end
    end

    context "when multiple topic ids are provided" do
      before { sign_in(admin) }

      it "regenerates the summaries" do
        put "/discourse-ai/summarization/regen_summary",
            params: {
              topic_ids: [topic.id, topic_1.id],
            }

        expect(response.status).to eq(200)
        expect(Jobs::StreamTopicAiSummary.jobs.size).to eq(2)

        job_topic_ids = Jobs::StreamTopicAiSummary.jobs.map { |j| j["args"].first["topic_id"] }
        expect(job_topic_ids).to contain_exactly(topic.id, topic_1.id)
      end
    end

    context "when more than 30 topics are provided" do
      before { sign_in(admin) }

      it "raises an error" do
        topics = 31.times.map { Fabricate(:topic) }
        topic_ids = topics.map(&:id)

        put "/discourse-ai/summarization/regen_summary", params: { topic_ids: topic_ids }

        expect(response.status).to eq(400)
      end
    end

    context "when user is not allowed to regenerate summaries" do
      fab!(:user)

      before { sign_in(user) }

      it "returns a 403" do
        put "/discourse-ai/summarization/regen_summary", params: { topic_id: topic.id }

        expect(response.status).to eq(403)
      end
    end

    context "when user cannot see the topic" do
      fab!(:moderator)

      before do
        group.add(moderator)
        sign_in(moderator)
      end

      it "returns a 403 for private topics user cannot access" do
        private_group = Fabricate(:group)
        private_category = Fabricate(:private_category, group: private_group)
        private_topic = Fabricate(:topic, category: private_category)

        put "/discourse-ai/summarization/regen_summary", params: { topic_id: private_topic.id }

        expect(response.status).to eq(403)
      end
    end
  end
end
