# frozen_string_literal: true

RSpec.describe "Managing decision models" do
  fab!(:admin)

  let(:form) { PageObjects::Components::FormKit.new(".ai-decision-model-editor") }

  before do
    enable_current_plugin
    sign_in(admin)
  end

  it "creates from a preset and tests the model" do
    DiscourseAi::Decisions.with_canned_answers(greeting: 0.97, red_image: 0.99) do
      visit "/admin/plugins/discourse-ai/ai-decision-models"
      find(".ai-decision-models-list-editor__empty-new-btn").click
      form.field("preset").select("vllm-sr-d3")
      form.field("url").fill_in("https://d3.example.com/v1/systemone")
      form.submit

      expect(page).to have_current_path(
        %r{\A/admin/plugins/discourse-ai/ai-decision-models/\d+/edit\z},
      )
      page.refresh
      expect(form.field("display_name")).to have_value("d3")
      expect(form.field("name")).to have_value("vllm-sr/d3")
      expect(form.field("provider")).to have_value("system_one")
      expect(form.field("url")).to have_value("https://d3.example.com/v1/systemone")
      expect(form.field("vision_enabled")).to be_checked
      find(".ai-decision-model-editor__test-btn").click
      expect(page).to have_css(
        ".ai-decision-model-editor__test-result.alert-success",
        text: "yes: 97%",
      )
      find(".back-button").click
      expect(page).to have_css(".ai-decision-models-list-editor__row", text: "d3")
    end
  end
end
