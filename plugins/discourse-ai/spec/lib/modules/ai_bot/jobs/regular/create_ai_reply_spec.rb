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
      persona_id = AiPersona.find_by(name: "Forum Helper").id

      bot_user = DiscourseAi::AiBot::EntryPoint.find_user_from_model("gpt-3.5-turbo")
      DiscourseAi::Completions::Llm.with_prepared_responses([expected_response]) do
        job.execute(post_id: topic.first_post.id, bot_user_id: bot_user.id, persona_id: persona_id)
      end

      expect(topic.posts.last.raw).to eq(expected_response)
    end
  end
end
