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

  it "keeps browser validation when submitting numeric choices and Unicode text" do
    form_template.update!(
      template: [
        {
          id: "text",
          type: "input",
          attributes: {
            label: "Text",
          },
          validations: {
            required: true,
            minimum: 2,
            maximum: 2,
            pattern: '(?:\p{Script=Greek}+|😀)',
          },
        },
        { id: "choice", type: "dropdown", choices: [1, 2, 3], attributes: { label: "Choice" } },
        {
          id: "choices",
          type: "multi-select",
          choices: [1.0, 2.5],
          attributes: {
            label: "Choices",
          },
        },
      ].as_json.to_yaml,
      output_template: nil,
    )
    composer = PageObjects::Components::Composer.new
    topic_page = PageObjects::Pages::Topic.new

    visit("/new-topic?category_id=#{category.id}")
    composer.fill_title("Browser validation and numeric choices")
    composer.form_template_field("dropdown").select("2")
    composer.form_template_field("multi-select").select("1")
    composer.fill_form_template_field("input", "ab")
    composer.create
    expect(composer).to have_form_template_field_error(
      I18n.t("js.form_templates.errors.pattern_mismatch"),
    )

    composer.fill_form_template_field("input", "α")
    composer.create
    expect(composer).to have_form_template_field_error(
      I18n.t("js.form_templates.errors.too_short", count: 2),
    )

    composer.fill_form_template_field("input", "😀")
    composer.create
    expect(topic_page).to have_post_content(post_number: 1, content: "Choice\n2\nChoices\n1")
    page.refresh
    expect(topic_page).to have_post_content(post_number: 1, content: "Choice\n2\nChoices\n1")
  end
end
