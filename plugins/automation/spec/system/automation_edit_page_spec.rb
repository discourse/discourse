# frozen_string_literal: true

describe "DiscourseAutomation | Edit page", type: :system do
  fab!(:admin)
  fab!(:automation) { Fabricate(:automation, enabled: true) }

  before do
    SiteSetting.discourse_automation_enabled = true
    sign_in(admin)
  end

  let(:automation_page) { PageObjects::Pages::Automation.new }

  it "has a toggle for turning on/off the automation" do
    automation_page.visit(automation)

    expect(automation_page.enabled_toggle).to be_checked

    automation_page.enabled_toggle.toggle
    automation_page.refresh

    expect(automation_page.enabled_toggle).to be_unchecked
    expect(automation.reload.enabled).to eq(false)

    automation_page.enabled_toggle.toggle
    automation_page.refresh

    expect(automation_page.enabled_toggle).to be_checked
    expect(automation.reload.enabled).to eq(true)
  end
end
