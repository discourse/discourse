# frozen_string_literal: true

describe "Edit category topic template" do
  fab!(:admin)
  fab!(:category)

  before { sign_in admin }

  let(:changes_banner) { PageObjects::Components::AdminChangesBanner.new }

  it "saves and displays a custom topic title placeholder" do
    browser_page
      .goto("/c/#{category.slug}/edit/topic-template")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }
    browser_root
      .locator("#category-topic-title-placeholder")
      .filter(visible: true)
      .fill("Describe your issue briefly")
    expect(changes_banner).to RSpecPredicates.be_visible
    changes_banner.click_save

    expect(category.reload.topic_title_placeholder).to eq("Describe your issue briefly")
  end
end
