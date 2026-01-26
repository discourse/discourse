# frozen_string_literal: true

RSpec.describe "Filtering templates by tags", type: :system do
  fab!(:current_user, :user)
  fab!(:templates_category, :category)
  fab!(:tag_1, :tag)
  fab!(:tag_2, :tag)
  fab!(:template_with_tag_1) do
    Fabricate(:template_item, category: templates_category, tags: [tag_1])
  end
  fab!(:template_with_tag_2) do
    Fabricate(:template_item, category: templates_category, tags: [tag_2])
  end
  fab!(:template_both_tags) do
    Fabricate(:template_item, category: templates_category, tags: [tag_1, tag_2])
  end
  fab!(:template_no_tags) { Fabricate(:template_item, category: templates_category) }
  fab!(:topic) { Fabricate(:post).topic }

  let(:templates_panel) { PageObjects::Components::DTemplatesPanel.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before do
    SiteSetting.discourse_templates_enabled = true
    SiteSetting.discourse_templates_categories = templates_category.id.to_s
    SiteSetting.tagging_enabled = true
    sign_in(current_user)
  end

  context "when filtering templates" do
    it "filters by tag and shows correct templates" do
      topic_page.visit_topic(topic)
      topic_page.click_reply_button

      templates_panel.open
      expect(templates_panel).to have_templates(
        template_with_tag_1,
        template_with_tag_2,
        template_both_tags,
        template_no_tags,
      )

      templates_panel.tag_drop.expand
      templates_panel.tag_drop.select_row_by_name(tag_1.name)
      expect(templates_panel).to have_templates(template_with_tag_1, template_both_tags)

      templates_panel.tag_drop.expand
      templates_panel.tag_drop.select_row_by_name(tag_2.name)
      expect(templates_panel).to have_templates(template_with_tag_2, template_both_tags)

      templates_panel.tag_drop.expand
      templates_panel.tag_drop.select_row_by_value("no-tags")
      expect(templates_panel).to have_templates(template_no_tags)
    end
  end
end
