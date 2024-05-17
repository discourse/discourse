# frozen_string_literal: true

describe "Wizard", type: :system do
  fab!(:admin)
  fab!(:topic) { Fabricate(:topic, title: "admin guide with 15 chars") }
  fab!(:post) { Fabricate(:post, topic: topic) }

  let(:wizard_page) { PageObjects::Pages::Wizard.new }

  before { sign_in(admin) }

  it "redirects to latest when wizard is completed" do
    visit("/wizard/steps/ready")
    wizard_page.click_jump_in

    expect(page).to have_current_path("/latest")
  end

  it "redirects to admin guide when wizard is completed and bootstrap mode is enabled" do
    SiteSetting.bootstrap_mode_enabled = true
    SiteSetting.admin_quick_start_topic_id = topic.id

    visit("/wizard/steps/ready")
    wizard_page.click_jump_in

    expect(page).to have_current_path("/t/admin-guide-with-15-chars/#{topic.id}")
  end
end
