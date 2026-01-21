# frozen_string_literal: true

describe "Edit Category Settings", type: :system do
  fab!(:admin)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:post) { Fabricate(:post, topic: topic) }

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
end
