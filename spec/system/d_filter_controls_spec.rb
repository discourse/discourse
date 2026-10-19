# frozen_string_literal: true

describe "DFilterControls" do
  fab!(:admin)

  let(:filter_controls) { PageObjects::Components::DFilterControls.new(".d-filter-controls") }

  before do
    sign_in(admin)

    poll_plugin = Plugin::Instance.parse_from_source(Rails.root.join("plugins/poll/plugin.rb").to_s)

    spoiler_alert_plugin =
      Plugin::Instance.parse_from_source(Rails.root.join("plugins/spoiler-alert/plugin.rb").to_s)

    Discourse.stubs(:plugins_sorted_by_name).returns([poll_plugin, spoiler_alert_plugin])
  end

  it "lets admins search plugins and reset matching or empty results" do
    page.visit("/admin/plugins")

    expect(page).to have_css(".admin-plugins-list__row", count: 2)
    expect(filter_controls).to have_disabled_reset_button
    expect(filter_controls).to have_no_no_results_reset_button

    filter_controls.type_in_search("poll")
    expect(page).to have_css(".admin-plugins-list__row", count: 1)

    filter_controls.clear_search
    expect(page).to have_css(".admin-plugins-list__row", count: 2)
    expect(filter_controls).to have_disabled_reset_button

    filter_controls.type_in_search("poll")
    expect(page).to have_css(".admin-plugins-list__row", count: 1)

    filter_controls.click_reset_button
    expect(filter_controls.search_input_value).to eq("")
    expect(page).to have_css(".admin-plugins-list__row", count: 2)

    filter_controls.type_in_search("xyznonexistent")
    expect(page).to have_css(".admin-plugins-list__row", count: 0)
    expect(filter_controls).to have_no_results_message
    expect(filter_controls).to have_no_results_reset_button

    filter_controls.click_no_results_reset_button
    expect(filter_controls.search_input_value).to eq("")
    expect(page).to have_css(".admin-plugins-list__row", count: 2)
    expect(filter_controls).to have_disabled_reset_button
  end

  it "lets admins filter plugins by status" do
    page.visit("/admin/plugins")

    filter_controls.select_dropdown_option("Enabled")
    expect(page).to have_css(".admin-plugins-list__row", count: 2)

    filter_controls.select_dropdown_option("Disabled")
    expect(page).to have_css(".admin-plugins-list__row", count: 0)

    filter_controls.select_dropdown_option("All")
    expect(page).to have_css(".admin-plugins-list__row", count: 2)
  end
end
