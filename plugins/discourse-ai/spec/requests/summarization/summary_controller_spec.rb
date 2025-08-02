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
      fab!(:user) { Fabricate(:leader) }

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
end
