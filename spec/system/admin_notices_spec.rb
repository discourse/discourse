# frozen_string_literal: true

describe "Admin Notices", type: :system do
  fab!(:admin)

  let(:admin_dashboard) { PageObjects::Pages::AdminDashboard.new }

  before do
    Fabricate(:admin_notice)

    I18n.backend.store_translations(:en, dashboard: { problem: { test_notice: "Houston" } })

    sign_in(admin)
  end

  it "supports dismissing admin notices" do
    admin_dashboard.visit

    expect(admin_dashboard).to have_admin_notice(I18n.t("dashboard.problem.test_notice"))

    admin_dashboard.dismiss_notice(I18n.t("dashboard.problem.test_notice"))

    expect(admin_dashboard).to have_no_admin_notice(I18n.t("dashboard.problem.test_notice"))
  end
end
