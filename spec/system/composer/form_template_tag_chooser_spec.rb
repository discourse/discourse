# frozen_string_literal: true

describe "Composer Form Template", type: :system do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:tag1) { Fabricate(:tag, name: "persian") }
  fab!(:tag2) { Fabricate(:tag, name: "siamese") }
  fab!(:tag_group) { Fabricate(:tag_group, name: "Cat Breeds", tags: [tag1, tag2]) }
  fab!(:form_template) do
    Fabricate(
      :form_template,
      name: "Cat Template",
      template:
        "- type: tag-chooser\n  id: cat-breed\n  tag_group: \"Cat Breeds\"\n  attributes:\n    label: \"Cat Breed\"\n    none_label: \"Select a breed\"\n    multiple: false\n  validations:\n    required: true\n- type: input\n  id: notes\n  attributes:\n    label: \"Notes\"\n",
    )
  end
  fab!(:category) do
    Fabricate(
      :category,
      name: "Cats",
      slug: "cats",
      topic_count: 2,
      form_template_ids: [form_template.id],
    )
  end

  let(:composer) { PageObjects::Components::Composer.new }

  before do
    SiteSetting.enable_form_templates = true
    SiteSetting.show_preview_for_form_templates = true
    SiteSetting.tagging_enabled = true
    sign_in(user)
  end

  it "uses tag name instead of tag ID in form template preview" do
    visit("/")
    find("#create-topic").click
    find(".category-chooser").click
    find(".category-row[data-value='#{category.id}']").click

    expect(page).to have_css(".form-template-field__multi-select[name='cat-breed']")

    find(".form-template-field__multi-select[name='cat-breed']").select("PERSIAN")

    preview = find(".d-editor-preview")
    expect(preview).to have_content("persian")
    expect(preview).to have_no_content(tag1.id.to_s)
  end
end
