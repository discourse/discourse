# frozen_string_literal: true

require "discourse_solved/seed_admin_dashboard_reports"

RSpec.describe DiscourseSolved::SeedAdminDashboardReports do
  before do
    SiteSetting.discourse_solved_admin_dashboard_seeded = false
    AdminDashboardReport.delete_all
    CategoryCustomField.where(name: "enable_accepted_answers").destroy_all
    SiteSetting.allow_solved_on_all_topics = false
  end

  describe "when solved is not in use anywhere" do
    it "does not seed and does not flip the marker" do
      expect { described_class.create }.not_to change { AdminDashboardReport.count }
      expect(SiteSetting.discourse_solved_admin_dashboard_seeded).to eq(false)
    end
  end

  describe "when allow_solved_on_all_topics is enabled" do
    before { SiteSetting.allow_solved_on_all_topics = true }

    it "seeds accepted_solutions and flips the marker" do
      described_class.create

      row = AdminDashboardReport.find_by(source: "core_report", identifier: "accepted_solutions")
      expect(row).to be_present
      expect(SiteSetting.discourse_solved_admin_dashboard_seeded).to eq(true)
    end

    it "places accepted_solutions at the end of the existing position range" do
      AdminDashboardReport.create!(source: "core_report", identifier: "signups", position: 0)
      AdminDashboardReport.create!(
        source: "core_report",
        identifier: "time_to_first_response",
        position: 1,
      )

      described_class.create

      row = AdminDashboardReport.find_by(identifier: "accepted_solutions")
      expect(row.position).to eq(2)
    end
  end

  describe "when at least one category has enable_accepted_answers set" do
    fab!(:category)

    before do
      CategoryCustomField.create!(
        category_id: category.id,
        name: "enable_accepted_answers",
        value: "true",
      )
    end

    it "seeds accepted_solutions" do
      described_class.create
      expect(AdminDashboardReport.exists?(identifier: "accepted_solutions")).to eq(true)
    end
  end

  describe "re-seed protection" do
    before { SiteSetting.allow_solved_on_all_topics = true }

    it "does nothing when the marker is already set" do
      SiteSetting.discourse_solved_admin_dashboard_seeded = true
      expect { described_class.create }.not_to change { AdminDashboardReport.count }
    end

    it "does not resurrect the row after the admin removes it" do
      described_class.create
      AdminDashboardReport.where(identifier: "accepted_solutions").destroy_all

      expect { described_class.create }.not_to change { AdminDashboardReport.count }
      expect(AdminDashboardReport.exists?(identifier: "accepted_solutions")).to eq(false)
    end
  end
end
