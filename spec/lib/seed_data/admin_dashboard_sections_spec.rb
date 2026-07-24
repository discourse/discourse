# frozen_string_literal: true

require "seed_data/admin_dashboard_sections"

describe SeedData::AdminDashboardSections do
  before { AdminDashboardSection.delete_all }

  it "seeds every known section, visible, in canonical order" do
    described_class.create

    rows = AdminDashboardSection.order(:position).pluck(:section_id, :position, :visible)
    expect(rows).to eq(
      [
        ["highlights", 0, true],
        ["reports", 1, true],
        ["traffic", 2, true],
        ["engagement", 3, true],
        ["search", 4, true],
      ],
    )
  end

  it "is idempotent and does not duplicate rows" do
    described_class.create
    described_class.create

    expect(AdminDashboardSection.count).to eq(
      AdminDashboardSectionConfiguration::KNOWN_SECTIONS.size,
    )
  end

  it "preserves existing visibility and position" do
    AdminDashboardSection.create!(section_id: "reports", position: 0, visible: false)

    described_class.create

    reports = AdminDashboardSection.find_by(section_id: "reports")
    expect(reports).to have_attributes(position: 0, visible: false)
  end

  it "re-adds a missing known section at the end" do
    described_class.create
    AdminDashboardSection.where(section_id: "engagement").delete_all

    described_class.create

    expect(AdminDashboardSection.order(:position).last).to have_attributes(
      section_id: "engagement",
      visible: true,
    )
  end
end
