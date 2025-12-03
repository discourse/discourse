# frozen_string_literal: true

describe "Assign | User Preferences", type: :system do
  fab!(:user)

  let(:selector) { "#control-notification_level_when_assigned .form-kit__control-select" }

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

    let(:form) { PageObjects::Components::FormKit.new(".topic-tracking") }
    let(:when_assigned) { form.field("notification_level_when_assigned") }

    it "shows the 'when assigned' tracking user preference" do
      visit "/my/preferences/tracking"

      expect(when_assigned).to have_value("watch_topic")
    end

    it "supports changing the 'when assigned' tracking user preference" do
      visit "/my/preferences/tracking"

      when_assigned.select("track_topic")
      form.submit()

      page.refresh

      expect(when_assigned).to have_value("track_topic")
    end
  end
end
