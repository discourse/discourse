# frozen_string_literal: true

describe "Edit Category Settings" do
  fab!(:admin)
  fab!(:category)

  let(:category_page) { PageObjects::Pages::Category.new }
  let(:category_default_view_select_kit) do
    PageObjects::Components::SelectKit.new("#category-default-view")
  end

  before { sign_in(admin) }

  describe "default view" do
    it "allows selecting hot as the default view" do
      category_page.visit_settings(category)

      category_default_view_select_kit.expand
      expect(category_default_view_select_kit).to have_option_value("hot")
      expect(category_default_view_select_kit).to have_option_value("latest")
      expect(category_default_view_select_kit).to have_option_value("top")

      category_default_view_select_kit.select_row_by_value("hot")
      category_page.save_settings

      expect(category_default_view_select_kit.value).to eq("hot")

      visit "/c/#{category.slug}/#{category.id}"
      expect(page).to have_css(".navigation-container .hot.active", text: "Hot")
    end
  end

  describe "topic posting review mode" do
    fab!(:group)

    let(:topic_posting_review_mode_select_kit) do
      PageObjects::Components::SelectKit.new(".topic-posting-review-mode .combo-box")
    end

    it "allows selecting 'everyone' mode" do
      category_page.visit_settings(category)

      topic_posting_review_mode_select_kit.expand
      topic_posting_review_mode_select_kit.select_row_by_value("everyone")
      category_page.save_settings

      expect(category.reload.category_setting.topic_posting_review_mode).to eq("everyone")
    end

    it "allows selecting 'everyone_except' mode with groups" do
      category_page.visit_settings(category)

      topic_posting_review_mode_select_kit.expand
      topic_posting_review_mode_select_kit.select_row_by_value("everyone_except")

      group_chooser =
        PageObjects::Components::SelectKit.new(".topic-posting-review-mode .group-chooser")
      group_chooser.expand
      group_chooser.select_row_by_value(group.id)

      category_page.save_settings

      category.reload
      expect(category.category_setting.topic_posting_review_mode).to eq("everyone_except")
      expect(category.topic_posting_review_group_ids).to contain_exactly(group.id)
    end

    it "clears groups when switching from group-based mode to simple mode" do
      category.category_setting.update_posting_review_mode!(
        :topic,
        :everyone_except,
        group_ids: [group.id],
      )

      category_page.visit_settings(category)

      topic_posting_review_mode_select_kit.expand
      topic_posting_review_mode_select_kit.select_row_by_value("no_one")
      category_page.save_settings

      category.reload
      expect(category.category_setting.topic_posting_review_mode).to eq("no_one")
      expect(category.topic_posting_review_group_ids).to be_empty
    end
  end
end
