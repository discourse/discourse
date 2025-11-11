# frozen_string_literal: true

describe "AdminFilterControls", type: :system do
  fab!(:admin)

  let(:filter_controls) do
    PageObjects::Components::AdminFilterControls.new(".admin-filter-controls")
  end

  before do
    sign_in(admin)

    poll_plugin =
      Plugin::Instance.parse_from_source(File.join(Rails.root, "plugins", "poll", "plugin.rb"))

    spoiler_alert_plugin =
      Plugin::Instance.parse_from_source(
        File.join(Rails.root, "plugins", "spoiler-alert", "plugin.rb"),
      )

    Discourse.stubs(:plugins_sorted_by_name).returns([poll_plugin, spoiler_alert_plugin])
  end

  describe "text filtering" do
    it "filters plugins by text input" do
      page.visit("/admin/plugins")

      expect(page).to have_css(".admin-filter-controls")
      expect(page).to have_css(".admin-plugins-list__row", count: 2)

      filter_controls.type_in_search("poll")
      expect(page).to have_css(".admin-plugins-list__row", count: 1)

      filter_controls.clear_search
      expect(page).to have_css(".admin-plugins-list__row", count: 2)
    end
  end

  describe "dropdown filtering" do
    it "filters plugins by dropdown selection" do
      page.visit("/admin/plugins")

      expect(page).to have_css(".admin-filter-controls")

      filter_controls.select_dropdown_option("Enabled")
      expect(page).to have_css(".admin-plugins-list__row", count: 2)

      filter_controls.select_dropdown_option("Disabled")
      expect(page).to have_css(".admin-plugins-list__row", count: 0)

      filter_controls.select_dropdown_option("All")
      expect(page).to have_css(".admin-plugins-list__row", count: 2)
    end
  end

  describe "reset functionality" do
    it "shows reset button when filters are active and no results" do
      page.visit("/admin/plugins")

      expect(page).to have_css(".admin-filter-controls")

      filter_controls.type_in_search("xyznonexistent")
      expect(page).to have_css(".admin-plugins-list__row", count: 0)
      expect(filter_controls).to have_reset_button

      filter_controls.click_reset_button
      expect(filter_controls.search_input_value).to eq("")
      expect(page).to have_css(".admin-plugins-list__row", count: 2)
    end

    it "does not show reset button when there are results" do
      page.visit("/admin/plugins")

      expect(page).to have_css(".admin-filter-controls")

      filter_controls.type_in_search("poll")
      expect(page).to have_css(".admin-plugins-list__row", count: 1)
      expect(filter_controls).to have_no_reset_button
    end
  end

  describe "no results message" do
    it "shows configurable no results message" do
      page.visit("/admin/plugins")

      expect(page).to have_css(".admin-filter-controls")

      filter_controls.type_in_search("xyznonexistent")
      expect(page).to have_css(".admin-plugins-list__row", count: 0)
      expect(filter_controls).to have_no_results_message
    end
  end
end
