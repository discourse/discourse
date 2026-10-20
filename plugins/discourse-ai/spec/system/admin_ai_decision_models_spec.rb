# frozen_string_literal: true

RSpec.describe "Managing decision models" do
  fab!(:admin)

  let(:form) { PageObjects::Components::FormKit.new(".ai-decision-model-editor") }

  before do
    enable_current_plugin
    SiteSetting.enable_discourse_workflows = true
    sign_in(admin)
  end

  it "keeps header fields aligned with the rest of the form at every layout size" do
    visit "/admin/plugins/discourse-ai/ai-decision-models/new"
    form.field("preset").select("jev-latest-vision")
    expect(form.field("provider")).to have_value("typesafe")

    [390, 1000, 1440].each do |width|
      resize_window(width: width) do
        try_until_success do
          name_rect = find('[data-name="display_name"] input').rect
          header_name_rect = find('[data-name="custom_headers.0.name"] input').rect
          header_value_rect = find('[data-name="custom_headers.0.value"] input').rect

          aggregate_failures("at #{width}px") do
            [header_name_rect, header_value_rect].each do |header_rect|
              expect(header_rect["x"]).to be_within(1).of(name_rect["x"])
              expect(header_rect["width"]).to be_within(1).of(name_rect["width"])
            end
            expect(header_value_rect["y"]).to be >
              header_name_rect["y"] + header_name_rect["height"]
          end
        end
      end
    end
  end

  it "creates from a preset and tests the model" do
    DiscourseAi::Decisions.with_canned_answers(greeting: 0.97, red_image: 0.99) do
      visit "/admin/plugins/discourse-ai/ai-models"
      find(".ai-models-list__new-button").click
      find("[data-model-type='decision'] button").click
      find("[data-template-id='vllm-sr-d3'] button").click
      expect(form.field("preset")).to have_value("vllm-sr-d3")
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
      expect(page).to have_css(".ai-models-list__row[data-model-type='decision']", text: "d3")
    end
  end
end
