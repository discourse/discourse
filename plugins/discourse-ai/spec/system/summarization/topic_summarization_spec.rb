# frozen_string_literal: true

RSpec.describe "Summarize a topic ", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:group)
  fab!(:topic)
  fab!(:post) do
    Fabricate(
      :post,
      topic: topic,
      raw:
        "I like to eat pie. It is a very good dessert. Some people are wasteful by throwing pie at others but I do not do that. I always eat the pie.",
    )
  end

  let(:summarization_result) { "This is a summary" }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:summary_box) { PageObjects::Components::AiSummaryTrigger.new }

  fab!(:ai_summary) { Fabricate(:ai_summary, target: topic, summarized_text: "This is a summary") }

  before do
    enable_current_plugin

    group.add(current_user)

    assign_fake_provider_to(:ai_default_llm_model)
    assign_persona_to(:ai_summarization_persona, [group.id])
    SiteSetting.ai_summarization_enabled = true

    sign_in(current_user)
  end

  context "when a summary is cached" do
    it "displays it" do
      topic_page.visit_topic(topic)
      summary_box.click_summarize
      expect(summary_box).to have_summary(summarization_result)
    end
  end

  context "when a summary is outdated" do
    fab!(:new_post) do
      Fabricate(
        :post,
        topic: topic,
        raw:
          "Idk, I think pie is overrated. I prefer cake. Cake is the best dessert. I always eat cake. I never throw it at people.",
      )
    end

    it "displays the new summary instead of a cached one" do
      topic_page.visit_topic(topic)
      summary_box.click_summarize
      summary_box.click_regenerate_summary
      expect(summary_box).to have_generating_summary_indicator
    end
  end
end
