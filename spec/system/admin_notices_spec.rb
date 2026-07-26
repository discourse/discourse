# frozen_string_literal: true

describe "Admin Notices" do
  let(:admin_dashboard) { PageObjects::Pages::AdminDashboard.new }

  before do
    Fabricate(:admin_notice)

    I18n.backend.store_translations(:en, dashboard: { problem: { test_notice: "Houston" } })
  end

  context "when signed in as admin" do
    fab!(:admin)

    before { sign_in(admin) }

    it "supports dismissing admin notices" do
      admin_dashboard.visit

      expect(admin_dashboard).to have_admin_notice(I18n.t("dashboard.problem.test_notice"))

      admin_dashboard.dismiss_notice(I18n.t("dashboard.problem.test_notice"))

      expect(admin_dashboard).to have_no_admin_notice(I18n.t("dashboard.problem.test_notice"))
    end

    it "warns the admin when the Sidekiq queue is too large" do
      Jobs.stubs(:last_job_performed_at).returns(1.second.ago)
      Jobs.stubs(:queued).returns(100_000)

      admin_dashboard.visit

      expect(admin_dashboard).to have_admin_notice(
        I18n.t("dashboard.problem.queue_size", queue_size: 100_000),
      )
    end

    it "warns the admin when Sidekiq is not processing queued jobs" do
      Jobs.stubs(:last_job_performed_at).returns(20.minutes.ago)
      Jobs.stubs(:queued).returns(1)

      admin_dashboard.visit

      message = Nokogiri::HTML5.fragment(I18n.t("dashboard.problem.sidekiq_check")).text
      expect(admin_dashboard).to have_admin_notice(message)
    end
  end

  context "when signed in as moderator" do
    fab!(:moderator)

    before { sign_in(moderator) }

    it "doesn't render dismiss button on admin notices" do
      admin_dashboard.visit

      expect(admin_dashboard).to have_admin_notice(I18n.t("dashboard.problem.test_notice"))
      expect(admin_dashboard).to have_no_css(
        ".dashboard-problem .btn",
        text: I18n.t("admin_js.admin.dashboard.dismiss_notice"),
      )
    end
  end
end
