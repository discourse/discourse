# frozen_string_literal: true

describe "Admin Dashboard Redesign | Site Advice section" do
  let(:dashboard) { PageObjects::Pages::AdminDashboard.new }

  before { SiteSetting.dashboard_improvements = true }

  context "when signed in as an admin" do
    fab!(:current_user, :admin)

    before { sign_in(current_user) }

    it "shows active problems in severity order and lets an admin ignore and refresh them" do
      dashboard.visit

      expect(dashboard).to have_no_site_advice

      Fabricate(:admin_notice, identifier: "host_names", priority: "low")
      resolved = Fabricate(:admin_notice, identifier: "starttls_disabled", priority: "high")

      dashboard.visit

      expect(dashboard).to have_site_advice_at_top
      expect(dashboard).to have_site_advice_title(
        "2 issues require your attention based on your site configuration",
      )
      expect(dashboard).to have_first_site_advice_problem("STARTTLS disabled")
      expect(dashboard).to have_site_advice_problem("default localhost hostname")
      expect(dashboard).to have_ignore_button_for("STARTTLS disabled")
      expect(dashboard).to have_ignore_button_for("default localhost hostname")
      expect(dashboard).to have_site_advice_refresh_button

      ProblemCheck.stubs(:realtime).returns(stub(run_all: nil))

      dashboard.ignore_site_advice_problem("default localhost hostname")

      expect(dashboard).to have_no_site_advice_problem("default localhost hostname")

      resolved.destroy!
      Fabricate(:admin_notice, identifier: "subfolder_ends_in_slash", priority: "low")

      dashboard.refresh_site_advice

      expect(dashboard).to have_no_site_advice_problem("default localhost hostname")
      expect(dashboard).to have_no_site_advice_problem("STARTTLS disabled")
      expect(dashboard).to have_site_advice_problem("subfolder setup is incorrect")
    end
  end

  context "when signed in as a moderator" do
    fab!(:moderator)

    before { sign_in(moderator) }

    it "shows the advice read-only, without any Ignore buttons" do
      Fabricate(:admin_notice, identifier: "host_names", priority: "low")

      dashboard.visit

      expect(dashboard).to have_site_advice
      expect(dashboard).to have_site_advice_problem("default localhost hostname")
      expect(dashboard).to have_no_ignore_buttons
      expect(dashboard).to have_site_advice_refresh_button
    end
  end
end
