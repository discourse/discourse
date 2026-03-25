# frozen_string_literal: true

describe "Admin upcoming changes sidebar interaction" do
  fab!(:current_user, :admin)
  let(:upcoming_changes_page) { PageObjects::Pages::AdminUpcomingChanges.new }
  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }
  let(:form_templates_link_css) do
    ".sidebar-section-link[data-link-name='admin_customize_form_templates']"
  end

  before do
    mock_upcoming_change_metadata(
      {
        enable_form_templates: {
          impact: "feature,all_members",
          status: :experimental,
          impact_type: "feature",
          impact_role: "all_members",
        },
      },
    )

    SiteSetting.enable_form_templates = false
    sign_in(current_user)
  end

  it "adds the form templates sidebar link when the upcoming change is enabled" do
    upcoming_changes_page.visit

    upcoming_changes_page.change_item(:enable_form_templates).select_enabled_for("everyone")
    expect(upcoming_changes_page).to have_enabled_for_success_toast("everyone")

    upcoming_changes_page.visit
    sidebar.toggle_all_sections

    expect(page).to have_css(form_templates_link_css)
  end

  it "removes the form templates sidebar link when the upcoming change is disabled" do
    SiteSetting.enable_form_templates = true
    upcoming_changes_page.visit

    upcoming_changes_page.change_item(:enable_form_templates).select_enabled_for("no_one")
    expect(upcoming_changes_page).to have_disabled_success_toast

    upcoming_changes_page.visit
    sidebar.toggle_all_sections

    expect(page).to have_no_css(form_templates_link_css)
  end
end
