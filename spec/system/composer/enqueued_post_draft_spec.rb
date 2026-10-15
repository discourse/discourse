# frozen_string_literal: true

describe "Composer draft after enqueued post" do
  fab!(:current_user) { Fabricate(:user, refresh_auto_groups: true) }

  let(:composer) { PageObjects::Components::Composer.new }
  let(:discard_draft_modal) { PageObjects::Modals::DiscardDraft.new }

  before { sign_in(current_user) }

  context "when creating a new topic that requires approval" do
    fab!(:category) { Fabricate(:category).tap { |c| c.update!(require_topic_approval: true) } }

    it "clears the draft and does not show the discard draft modal when reopening the composer" do
      browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      browser_root.locator("#create-topic").filter(visible: true).click
      expect(composer).to be_opened

      composer.fill_title("This is a test topic requiring approval")
      composer.fill_content("This is the body of a test topic that requires admin approval")
      composer.switch_category(category.name)

      composer.create

      expect(
        browser_root.locator(".post-enqueued-modal").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      browser_root.locator(".post-enqueued-modal .btn-primary").filter(visible: true).click
      expect(
        browser_root.locator(".post-enqueued-modal").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
      expect(composer).to be_closed

      try_until_success { expect(Draft.where(user: current_user).count).to eq(0) }

      browser_root.locator("#create-topic").filter(visible: true).click

      expect(discard_draft_modal).to be_closed
      expect(composer).to be_opened
    end
  end
end
