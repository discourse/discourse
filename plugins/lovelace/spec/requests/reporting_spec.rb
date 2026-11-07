# frozen_string_literal: true

RSpec.describe "Lovelace reporting" do
  fab!(:admin)
  fab!(:user)

  before { enable_current_plugin }

  it "serves standard reports to administrators and denies regular members and anonymous visitors" do
    get "/admin/reports/lovelace_onboarding.json"
    expect(response.status).to eq(404)
    sign_in(user)
    get "/admin/reports/lovelace_onboarding.json"
    expect(response.status).to eq(404)
    put "/lovelace/member-checklist.json", params: { seen: true }, as: :json
    expect(response.status).to eq(200)
    put "/lovelace/member-checklist.json", params: { seen: "true" }, as: :json
    expect(response.status).to eq(400)
    sign_in(admin)
    get "/admin/reports/lovelace_onboarding.json"
    expect(response.status).to eq(200)
    expect(response.parsed_body["report"]["data"]).to include(
      "activity" => I18n.t("lovelace.reporting.seen"),
      "count" => 1,
    )
    get "/admin/reports/lovelace_onboarding_items.json"
    expect(response.status).to eq(200)
    expect(response.parsed_body["report"]["data"].size).to eq(3)
  end

  it "validates clicked item IDs, preserves member progress and isolates click activity" do
    put "/lovelace/member-checklist.json",
        params: {
          seen: true,
          clicked_item_id: "profile",
        },
        as: :json
    expect(response.status).to eq(403)
    sign_in(user)
    ["missing", nil, ["profile"]].each do |invalid_id|
      put "/lovelace/member-checklist.json",
          params: {
            seen: true,
            clicked_item_id: invalid_id,
          },
          as: :json
      expect(response.status).to eq(400)
    end
    expect(Lovelace::Reporting.summary["seen"]).to eq(0)
    put "/lovelace/member-checklist.json",
        params: {
          seen: true,
          clicked_item_id: "profile",
          user_id: admin.id,
        },
        as: :json
    expect(response.status).to eq(200)
    expect(response.parsed_body).to include(
      "completed_ids" => [],
      "minimized" => false,
      "dismissed" => false,
    )
    expect(response.parsed_body).not_to have_key("reporting")
    sign_in(admin)
    get "/lovelace/member-checklist.json"
    expect(response.parsed_body["completed_ids"]).to eq([])
    get "/admin/reports/lovelace_onboarding_items.json"
    expect(response.parsed_body["report"]["data"]).to include(
      "activity" => I18n.t("lovelace.items.profile.title"),
      "clicked_count" => 1,
      "count" => 0,
    )
    SiteSetting.lovelace_enabled = false
    put "/lovelace/member-checklist.json",
        params: {
          seen: true,
          clicked_item_id: "profile",
        },
        as: :json
    expect(response.status).to eq(404)
  end
end
