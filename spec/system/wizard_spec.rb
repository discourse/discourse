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
end
