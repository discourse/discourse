# frozen_string_literal: true

require "rails_helper"

describe Jobs::DeleteHiddenQueries do
  before do
    Jobs.run_immediately!
    SiteSetting.data_explorer_enabled = true
  end

  it "will correctly destroy old hidden queries" do
    DiscourseDataExplorer::Query.create!(
      id: 1,
      name: "A",
      description: "A description for A",
      sql: "SELECT 1 as value",
      hidden: false,
      last_run_at: 2.days.ago,
      updated_at: 2.days.ago,
    )
    DiscourseDataExplorer::Query.create!(
      id: 2,
      name: "B",
      description: "A description for B",
      sql: "SELECT 1 as value",
      hidden: true,
      last_run_at: 8.days.ago,
      updated_at: 8.days.ago,
    )
    DiscourseDataExplorer::Query.create!(
      id: 3,
      name: "C",
      description: "A description for C",
      sql: "SELECT 1 as value",
      hidden: true,
      last_run_at: 4.days.ago,
      updated_at: 4.days.ago,
    )
    DiscourseDataExplorer::Query.create!(
      id: 4,
      name: "D",
      description: "A description for D",
      sql: "SELECT 1 as value",
      hidden: true,
      last_run_at: nil,
      updated_at: 10.days.ago,
    )
    DiscourseDataExplorer::Query.create!(
      id: 5,
      name: "E",
      description: "A description for E",
      sql: "SELECT 1 as value",
      hidden: true,
      last_run_at: 5.days.ago,
      updated_at: 10.days.ago,
    )
    DiscourseDataExplorer::Query.create!(
      id: 6,
      name: "F",
      description: "A description for F",
      sql: "SELECT 1 as value",
      hidden: true,
      last_run_at: 10.days.ago,
      updated_at: 5.days.ago,
    )

    described_class.new.execute(nil)
    expect(DiscourseDataExplorer::Query.all.length).to eq(4)
  end
end
