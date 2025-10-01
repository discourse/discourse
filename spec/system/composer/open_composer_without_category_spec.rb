# frozen_string_literal: true

require "rails_helper"

describe "Composer category selection", type: :system do
  fab!(:moderator)
  fab!(:default_category) { Fabricate(:category, name: "Features", slug: "features") }

  let(:category_page) { PageObjects::Pages::Category.new }
  let(:composer) { PageObjects::Components::Composer.new }

  before { SiteSetting.default_composer_category = default_category.id }

  context "when open_composer_without_category is enabled" do
    before { SiteSetting.open_composer_without_category = true }

    it "opens the composer with no category selected" do
      sign_in(moderator)
      category_page.visit(default_category)
      category_page.new_topic_button.click

      expect(composer).to be_opened

      expect(page).not_to have_selector(".category-chooser .badge-category__name")
    end
  end

  context "when open_composer_without_category is disabled" do
    before { SiteSetting.open_composer_without_category = false }

    it "opens the composer with a category pre-selected" do
      sign_in(moderator)
      category_page.visit(default_category)
      category_page.new_topic_button.click

      expect(composer).to be_opened

      expect(page).to have_selector(".category-chooser .badge-category__name")
    end
  end
end
