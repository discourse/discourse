# frozen_string_literal: true

RSpec.describe Lovelace::MemberChecklistsController do
  fab!(:user)
  fab!(:other_user, :user)

  before { enable_current_plugin }

  it "requires login and respects the plugin setting" do
    get "/lovelace/member-checklist.json"
    expect(response.status).to eq(403)
    put "/lovelace/member-checklist.json", params: { dismissed: true }, as: :json
    expect(response.status).to eq(403)
    sign_in(user)
    SiteSetting.lovelace_enabled = false
    get "/lovelace/member-checklist.json"
    expect(response.status).to eq(404)
    put "/lovelace/member-checklist.json", params: { dismissed: true }, as: :json
    expect(response.status).to eq(404)
  end

  it "saves completion, reversal, minimization and dismissal independently for each member" do
    sign_in(user)
    put "/lovelace/member-checklist.json",
        params: {
          item_id: "profile",
          completed: true,
        },
        as: :json
    expect(response.status).to eq(200)
    expect(response.parsed_body["completed_ids"]).to eq(["profile"])
    put "/lovelace/member-checklist.json", params: { minimized: true }, as: :json
    put "/lovelace/member-checklist.json", params: { dismissed: true }, as: :json
    get "/lovelace/member-checklist.json"
    expect(response.parsed_body).to include(
      "completed_ids" => ["profile"],
      "minimized" => true,
      "dismissed" => true,
    )
    sign_in(other_user)
    get "/lovelace/member-checklist.json"
    expect(response.parsed_body).to include(
      "completed_ids" => [],
      "minimized" => false,
      "dismissed" => false,
    )
    sign_in(user)
    put "/lovelace/member-checklist.json",
        params: {
          item_id: "profile",
          completed: false,
        },
        as: :json
    expect(response.parsed_body["completed_ids"]).to eq([])
  end

  it "saves final completion and dismissal together while preserving other members' state" do
    sign_in(user)
    %w[profile_picture profile].each do |id|
      put "/lovelace/member-checklist.json",
          params: {
            item_id: id,
            completed: true,
            seen: true,
          },
          as: :json
      expect(response.status).to eq(200)
      expect(response.parsed_body["dismissed"]).to eq(false)
    end
    put "/lovelace/member-checklist.json",
        params: {
          item_id: "guidelines",
          completed: true,
          seen: true,
        },
        as: :json
    expect(response.status).to eq(200)
    expect(response.parsed_body).to include(
      "completed_ids" => %w[profile_picture profile guidelines],
      "dismissed" => true,
    )
    get "/lovelace/member-checklist.json"
    expect(response.parsed_body["dismissed"]).to eq(true)
    expect(Lovelace::Reporting.summary).to include(
      "completed" => 1,
      "dismissed" => 1,
      "dismissed_without_completion" => 0,
    )
    sign_in(other_user)
    get "/lovelace/member-checklist.json"
    expect(response.parsed_body).to include("completed_ids" => [], "dismissed" => false)
  end

  it "retains progress through edits and starts new item IDs incomplete" do
    sign_in(user)
    put "/lovelace/member-checklist.json",
        params: {
          item_id: "profile",
          completed: true,
        },
        as: :json
    items = Lovelace::Checklist.seeded_items
    items.find { |item| item["id"] == "profile" }["title"] = "Updated profile title"
    PluginStore.set(Lovelace::PLUGIN_NAME, "checklist", { "items" => items, "revision" => 1 })
    get "/lovelace/member-checklist.json"
    expect(response.parsed_body["completed_ids"]).to eq(["profile"])
    expect(response.parsed_body["items"]).to eq(items)
    PluginStore.set(Lovelace::PLUGIN_NAME, "checklist", { "items" => [], "revision" => 2 })
    get "/lovelace/member-checklist.json"
    expect(response.parsed_body).to include("items" => [], "completed_ids" => [])
  end

  it "uses the editable configuration and rejects unknown items and invalid state" do
    sign_in(user)
    items = Lovelace::Checklist.seeded_items.first(1)
    PluginStore.set(Lovelace::PLUGIN_NAME, "checklist", { "items" => items, "revision" => 1 })
    get "/lovelace/member-checklist.json"
    expect(response.parsed_body["items"]).to eq(items)
    put "/lovelace/member-checklist.json",
        params: {
          item_id: "missing",
          completed: true,
        },
        as: :json
    expect(response.status).to eq(400)
    put "/lovelace/member-checklist.json", params: { minimized: "false" }, as: :json
    expect(response.status).to eq(400)
    get "/lovelace/member-checklist.json"
    expect(response.parsed_body).to include("completed_ids" => [], "minimized" => false)
  end
end
