# frozen_string_literal: true

RSpec.describe Jobs::CreateAiReply do
  subject(:job) { described_class.new }

  fab!(:gpt_35_bot) { Fabricate(:llm_model, name: "gpt-3.5-turbo") }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    toggle_enabled_bots(bots: [gpt_35_bot])
  end

  describe "#execute" do
    fab!(:topic)
    fab!(:post) { Fabricate(:post, topic: topic) }

    let(:expected_response) do
      "Hello this is a bot and what you just said is an interesting question"
    end

    before { SiteSetting.min_personal_message_post_length = 5 }

    it "adds a reply from the bot" do
      agent_id = AiAgent.find_by(name: "Forum Helper").id
      bot_user = DiscourseAi::AiBot::EntryPoint.find_user_from_model("gpt-3.5-turbo")
      authorization_user = topic.first_post.user

      DiscourseAi::Completions::Llm.with_prepared_responses([expected_response]) do
        job.execute(
          post_id: topic.first_post.id,
          bot_user_id: bot_user.id,
          agent_id: agent_id,
          authorization_user_id: authorization_user.id,
        )
      end

      bot_reply = topic.posts.last

      aggregate_failures do
        expect(bot_reply.raw).to eq(expected_response)
        expect(
          bot_reply.custom_fields[
            DiscourseAi::AiBot::POST_AI_AGENT_AUTHORIZATION_USER_ID_FIELD
          ].to_i,
        ).to eq(authorization_user.id)
      end
    end

    it "does not reply when an explicit authorization user is missing" do
      agent_id = AiAgent.find_by(name: "Forum Helper").id
      bot_user = DiscourseAi::AiBot::EntryPoint.find_user_from_model("gpt-3.5-turbo")

      expect {
        DiscourseAi::Completions::Llm.with_prepared_responses([expected_response]) do
          job.execute(
            post_id: topic.first_post.id,
            bot_user_id: bot_user.id,
            agent_id: agent_id,
            authorization_user_id: nil,
          )
        end
      }.not_to change { topic.posts.count }
    end

    it "falls back to the post author for jobs enqueued without authorization provenance" do
      agent_id = AiAgent.find_by(name: "Forum Helper").id
      bot_user = DiscourseAi::AiBot::EntryPoint.find_user_from_model("gpt-3.5-turbo")

      DiscourseAi::Completions::Llm.with_prepared_responses([expected_response]) do
        job.execute(post_id: topic.first_post.id, bot_user_id: bot_user.id, agent_id: agent_id)
      end

      expect(topic.posts.last.raw).to eq(expected_response)
    end

    it "records authorization provenance before streaming generation fails" do
      agent_id = AiAgent.find_by(name: "Forum Helper").id
      bot_user = DiscourseAi::AiBot::EntryPoint.find_user_from_model("gpt-3.5-turbo")
      authorization_user = Fabricate(:user, refresh_auto_groups: true)
      pm_topic = Fabricate(:private_message_topic, user: authorization_user, recipient: bot_user)
      prompt_post = Fabricate(:post, topic: pm_topic, user: authorization_user)

      expect {
        DiscourseAi::Completions::Llm.with_prepared_responses([]) do
          job.execute(
            post_id: prompt_post.id,
            bot_user_id: bot_user.id,
            agent_id: agent_id,
            authorization_user_id: authorization_user.id,
          )
        end
      }.to raise_error(DiscourseAi::Completions::Endpoints::CannedResponse::CANNED_RESPONSE_ERROR)

      bot_reply = pm_topic.posts.order(:post_number).last

      expect(
        bot_reply.custom_fields[DiscourseAi::AiBot::POST_AI_AGENT_AUTHORIZATION_USER_ID_FIELD].to_i,
      ).to eq(authorization_user.id)
    end
  end
end
