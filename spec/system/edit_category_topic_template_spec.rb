# frozen_string_literal: true

describe "Edit category topic template" do
  fab!(:admin)
  fab!(:category)

  before { sign_in admin }

  let(:changes_banner) { PageObjects::Components::AdminChangesBanner.new }

  context "with simplified category creation" do
    before { SiteSetting.enable_simplified_category_creation = true }

    it "saves and displays a custom topic title placeholder" do
      visit "/c/#{category.slug}/edit/topic-template"
      find("#category-topic-title-placeholder").fill_in(with: "Describe your issue briefly")
      expect(changes_banner).to be_visible
      changes_banner.click_save

      expect(category.reload.topic_title_placeholder).to eq("Describe your issue briefly")
    end
  end

  context "with legacy category editing" do
    it "saves and displays a custom topic title placeholder" do
      visit "/c/#{category.slug}/edit/topic-template"
      find("#category-topic-title-placeholder").fill_in(with: "Describe your issue briefly")

      # sleep to account for debounce
      sleep 0.6
      find("#save-category").click

      expect(category.reload.topic_title_placeholder).to eq("Describe your issue briefly")
    end
  end
end
