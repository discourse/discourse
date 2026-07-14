# frozen_string_literal: true

describe "Edit Category Settings" do
  fab!(:admin)
  fab!(:category)

  let(:category_page) { PageObjects::Pages::Category.new }
  let(:form) { PageObjects::Components::FormKit.new(".form-kit") }
  let(:category_default_view_select_kit) do
    PageObjects::Components::SelectKit.new("#category-default-view")
  end

  before { sign_in(admin) }

  describe "default view" do
    it "allows selecting hot as the default view" do
      category_page.visit_appearance(category)

      form.field("default_view").select("hot")
      category_page.save_settings

      expect(form.field("default_view").value).to eq("hot")

      visit "/c/#{category.slug}/#{category.id}"
      expect(page).to have_css(".navigation-container .hot.active", text: "Hot")
    end
  end

  describe "topic posting review mode" do
    fab!(:group)

    let(:dialog) { PageObjects::Components::Dialog.new }

    it "allows selecting 'everyone' mode" do
      category_page.visit_moderation(category)

      category_page.topic_posting_review_mode_chooser.expand
      category_page.topic_posting_review_mode_chooser.select_row_by_value("everyone")
      category_page.save_settings

      category_page.visit_moderation(category)
      expect(category_page).to have_topic_posting_review_mode("everyone")
    end

    it "allows selecting 'everyone_except' mode with groups" do
      category_page.visit_moderation(category)

      category_page.topic_posting_review_mode_chooser.expand
      category_page.topic_posting_review_mode_chooser.select_row_by_value("everyone_except")
      category_page.topic_posting_review_mode_chooser.collapse

      category_page.save_settings
      expect(form.field("topic_posting_review_group_ids")).to have_errors(
        I18n.t("js.category.validations.groups_required"),
      )

      category_page.topic_posting_review_group_chooser.expand
      category_page.topic_posting_review_group_chooser.select_row_by_value(group.id)
      category_page.topic_posting_review_group_chooser.collapse

      category_page.save_settings

      category_page.visit_moderation(category)
      expect(category_page).to have_topic_posting_review_mode("everyone_except")
      expect(category_page).to have_topic_posting_review_groups(group)
    end
  end
end
