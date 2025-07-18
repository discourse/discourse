# frozen_string_literal: true

describe "Assign | User Preferences", type: :system, js: true do
  fab!(:user)

  let(:selector) { "[data-setting-name='user-notification-level-when-assigned'] .combobox" }

  before { sign_in(user) }

  describe "when discourse-assign is disabled" do
    before { SiteSetting.assign_enabled = false }

    it "does not show the 'when assigned' tracking user preference" do
      visit "/my/preferences/tracking"

      expect(page).not_to have_css(selector)
    end
  end

  describe "when discourse-assign is enabled" do
    before { SiteSetting.assign_enabled = true }

    let(:when_assigned) { PageObjects::Components::SelectKit.new(selector) }

    it "shows the 'when assigned' tracking user preference" do
      visit "/my/preferences/tracking"

      expect(when_assigned).to have_selected_value("watch_topic")
    end

    it "supports changing the 'when assigned' tracking user preference" do
      visit "/my/preferences/tracking"

      when_assigned.expand
      when_assigned.select_row_by_value("track_topic")

      page.find("button.save-changes").click
      page.refresh

      expect(when_assigned).to have_selected_value("track_topic")
    end
  end
end
