# frozen_string_literal: true

describe "Admin upcoming changes", type: :system do
  fab!(:current_user, :admin)
  let(:upcoming_changes_page) { PageObjects::Pages::AdminUpcomingChanges.new }

  before do
    SiteSetting.enable_upcoming_changes = true

    mock_upcoming_change_metadata(
      {
        enable_upload_debug_mode: {
          impact: "other,developers",
          status: :pre_alpha,
          impact_type: "other",
          impact_role: "developers",
        },
        about_page_extra_groups_show_description: {
          impact: "feature,all_members",
          status: :stable,
          impact_type: "feature",
          impact_role: "all_members",
        },
      },
    )

    sign_in(current_user)
  end

  it "shows a list of upcoming changes and their metadata" do
    upcoming_changes_page.visit
    expect(upcoming_changes_page).to have_change(:about_page_extra_groups_show_description)
    expect(upcoming_changes_page).to have_change(:enable_upload_debug_mode)

    expect(
      upcoming_changes_page.change_row(:about_page_extra_groups_show_description),
    ).to have_status(:stable)
    expect(
      upcoming_changes_page.change_row(:about_page_extra_groups_show_description),
    ).to have_impact_role(:all_members)
  end

  it "shows upcoming changes from plugins" do
    upcoming_changes_page.visit
    expect(upcoming_changes_page).to have_change(:enable_experimental_sample_plugin_feature)
    expect(
      upcoming_changes_page.change_row(:enable_experimental_sample_plugin_feature),
    ).to have_plugin_name("Sample plugin")
  end

  it "can toggle an upcoming change on or off" do
    upcoming_changes_page.visit

    expect(upcoming_changes_page.change_row(:enable_upload_debug_mode)).to be_disabled
    upcoming_changes_page.change_row(:enable_upload_debug_mode).toggle
    expect(page).to have_content(I18n.t("admin_js.admin.upcoming_changes.change_enabled"))
    expect(upcoming_changes_page.change_row(:enable_upload_debug_mode)).to be_enabled

    # Revisit the page to skip the 3s toggle rate limit
    upcoming_changes_page.visit
    expect(upcoming_changes_page.change_row(:enable_upload_debug_mode)).to be_enabled
    upcoming_changes_page.change_row(:enable_upload_debug_mode).toggle
    expect(page).to have_content(I18n.t("admin_js.admin.upcoming_changes.change_disabled"))
  end

  # TODO (martin) Add these specs
  # it "can add and remove groups for a change" do
  # end

  # it "can filter by name, description, plugin, status, impact type, or impact role" do
  # end
end
