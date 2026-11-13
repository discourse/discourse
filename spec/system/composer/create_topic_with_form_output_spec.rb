# frozen_string_literal: true

RSpec.describe "Create topic with form output" do
  fab!(:user) { Fabricate(:user, trust_level: 2) }
  fab!(:form_template) do
    Fabricate(
      :form_template,
      template: [
        {
          id: "description",
          type: "textarea",
          attributes: {
            label: "Details",
          },
          validations: {
            required: true,
          },
        },
      ].as_json.to_yaml,
      output_template: "## Invitation\n{{ answers.description }}",
    )
  end
  fab!(:category) { Fabricate(:category, form_template_ids: [form_template.id]) }

  before do
    SiteSetting.enable_form_templates = true
    SiteSetting.show_preview_for_form_templates = true
    sign_in(user)
  end

  it "uses the custom server output in preview and the saved topic" do
    visit("/new-topic?category_id=#{category.id}")
    find("#reply-title").fill_in(with: "An invitation from a structured form")
    find("textarea[name='description']").fill_in(
      with: "A sufficiently long description for our invitation.",
    )
    expect(page).to have_css(".d-editor-preview h2", text: "Invitation")
    expect(page).to have_css(
      ".d-editor-preview",
      text: "A sufficiently long description for our invitation.",
    )
    find(".save-or-cancel .create").click
    expect(page).to have_css(".topic-post h2", text: "Invitation")
    page.refresh
    expect(page).to have_css(".topic-post h2", text: "Invitation")
    expect(page).to have_css(
      ".topic-post",
      text: "A sufficiently long description for our invitation.",
    )
  end
end
