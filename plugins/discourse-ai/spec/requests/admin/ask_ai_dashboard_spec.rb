# frozen_string_literal: true

describe Admin::DashboardController do
  fab!(:admin)
  fab!(:moderator)

  before do
    enable_current_plugin
    SiteSetting.dashboard_improvements = true
    SiteSetting.ai_ask_ai_enabled = true
    AdminDashboardSectionConfiguration.all_known_section_ids.each_with_index do |id, index|
      AdminDashboardSection.find_or_initialize_by(section_id: id).update!(
        position: index,
        visible: id == "ask_ai",
      )
    end
  end

  it "serves Ask metrics through the dashboard date range" do
    AskAiLog.create!(
      user: admin,
      query: "Private question",
      asked_at: "2026-09-01 12:00:00",
      ask_outcome: :answered,
    )
    sign_in(admin)

    get "/admin/dashboard.json", params: { start_date: "2026-09-01", end_date: "2026-09-01" }

    expect(response.status).to eq(200)
    section = response.parsed_body["sections"].find { |item| item["id"] == "ask_ai" }
    expect(section["data"]).to include("questions" => 1, "askers" => 1)
    expect(section["data"]).not_to have_key("query")
  end

  it "withholds Ask metrics from moderators" do
    sign_in(moderator)

    get "/admin/dashboard.json"

    expect(response.status).to eq(200)
    section = response.parsed_body["sections"].find { |item| item["id"] == "ask_ai" }
    expect(section["data"]).to be_nil
  end

  it "omits the section and configuration entry when Ask AI is disabled" do
    sign_in(admin)
    SiteSetting.ai_ask_ai_enabled = false

    get "/admin/dashboard.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body["sections"].pluck("id")).not_to include("ask_ai")
    expect(response.parsed_body.dig("configuration", "sections").pluck("id")).not_to include(
      "ask_ai",
    )
  end
end
