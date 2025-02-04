# frozen_string_literal: true

describe "DiscourseAutomation | smoke test", type: :system do
  fab!(:admin)
  fab!(:group) { Fabricate(:group, name: "test") }
  fab!(:badge) { Fabricate(:badge, name: "badge") }

  before do
    SiteSetting.discourse_automation_enabled = true
    sign_in(admin)
  end

  context "when default_value fields are set" do
    before do
      DiscourseAutomation::Scriptable.add("test") do
        triggerables %i[post_created_edited]
        field :test, component: :text, default_value: "test-default-value"
      end
    end

    after { DiscourseAutomation::Scriptable.remove("test") }

    it "populate correctly" do
      visit("/admin/plugins/discourse-automation")
      find(".admin-section-landing__header-filter").set("test")
      find(".admin-section-landing-item__content", match: :first).click
      fill_in("automation-name", with: "aaaaa")
      select_kit = PageObjects::Components::SelectKit.new(".triggerables")
      select_kit.expand
      select_kit.select_row_by_value("post_created_edited")

      expect(find(".field input[name=test]").value).to eq("test-default-value")
    end
  end

  it "works" do
    visit("/admin/plugins/discourse-automation")

    find(".admin-section-landing__header-filter").set("user group membership through badge")
    find(".admin-section-landing-item__content", match: :first).click
    fill_in("automation-name", with: "aaaaa")
    select_kit = PageObjects::Components::SelectKit.new(".triggerables")
    select_kit.expand
    select_kit.select_row_by_value("user_first_logged_in")
    select_kit = PageObjects::Components::SelectKit.new(".fields-section .combo-box")
    select_kit.expand
    select_kit.select_row_by_name("badge")
    select_kit = PageObjects::Components::SelectKit.new(".group-chooser")
    select_kit.expand
    select_kit.select_row_by_name("test")
    find(".automation-enabled input").click
    find(".update-automation").click

    expect(page).to have_css('[role="button"]', text: "aaaaa")
  end
end
