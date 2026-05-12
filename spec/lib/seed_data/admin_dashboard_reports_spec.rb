# frozen_string_literal: true

require "seed_data/admin_dashboard_reports"

RSpec.describe SeedData::AdminDashboardReports do
  subject(:seeder) { described_class.new }

  before do
    SiteSetting.admin_dashboard_reports_seeded = false
    AdminDashboardReport.delete_all
  end

  describe "first-time seed" do
    it "seeds daily_engaged_users and time_to_first_response in order" do
      seeder.create

      rows = AdminDashboardReport.order(:position).pluck(:source, :identifier, :position)
      expect(rows).to eq(
        [["core_report", "daily_engaged_users", 0], ["core_report", "time_to_first_response", 1]],
      )
    end

    it "flips the marker site setting after seeding" do
      seeder.create
      expect(SiteSetting.admin_dashboard_reports_seeded).to eq(true)
    end
  end

  describe "re-seed protection" do
    it "does nothing when the marker is already set" do
      SiteSetting.admin_dashboard_reports_seeded = true
      expect { seeder.create }.not_to change { AdminDashboardReport.count }
    end

    it "does not resurrect removed defaults on subsequent calls" do
      seeder.create
      AdminDashboardReport.where(identifier: "daily_engaged_users").destroy_all

      expect { seeder.create }.not_to change { AdminDashboardReport.count }
      expect(AdminDashboardReport.exists?(identifier: "daily_engaged_users")).to eq(false)
    end
  end
end
