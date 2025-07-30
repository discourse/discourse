#frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Tools::Summarize do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  let(:progress_blk) { Proc.new {} }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  let(:summary) { "summary stuff" }

  describe "#process" do
    it "can generate correct info" do
      post = Fabricate(:post)

      DiscourseAi::Completions::Llm.with_prepared_responses([summary]) do
        summarization =
          described_class.new(
            { topic_id: post.topic_id, guidance: "why did it happen?" },
            bot_user: bot_user,
            llm: llm,
          )
        info = summarization.invoke(&progress_blk)

        expect(info).to include("Topic summarized")
        expect(summarization.custom_raw).to include(summary)
        expect(summarization.chain_next_response?).to eq(false)
      end
    end

    it "protects hidden data" do
      category = Fabricate(:category)
      category.set_permissions({})
      category.save!

      topic = Fabricate(:topic, category_id: category.id)
      post = Fabricate(:post, topic: topic)

      DiscourseAi::Completions::Llm.with_prepared_responses([summary]) do
        summarization =
          described_class.new(
            { topic_id: post.topic_id, guidance: "why did it happen?" },
            bot_user: bot_user,
            llm: llm,
          )
        info = summarization.invoke(&progress_blk)

        expect(info).not_to include(post.raw)

        expect(summarization.custom_raw).to eq(I18n.t("discourse_ai.ai_bot.topic_not_found"))
      end
    end
  end
end
