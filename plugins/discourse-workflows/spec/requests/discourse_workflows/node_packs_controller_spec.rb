# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NodePacksController do
  fab!(:admin)
  fab!(:user)

  let(:manifest) do
    File.read(Rails.root.join("plugins/discourse-workflows/docs/examples/node-packs/jev.json"))
  end
  let(:base_path) { "/admin/plugins/discourse-workflows/node-packs" }

  before { sign_in(admin) }

  it "previews, installs, lists, shows, updates, exports, and removes a pack" do
    post "#{base_path}/preview.json", params: { manifest: }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("preview", "nodes").length).to eq(4)

    post "#{base_path}.json",
         params: {
           manifest:,
           approved_destinations: ["https://api.typesafe.ai"],
         }
    expect(response).to have_http_status(:created)
    pack = response.parsed_body.fetch("node_pack")
    expect(pack).to include("key" => "jev", "node_count" => 4, "used_by_count" => 0)

    get "#{base_path}.json"
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("meta", "total_rows")).to eq(1)

    get "#{base_path}/#{pack.fetch("id")}.json"
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("node_pack", "nodes").length).to eq(4)

    put "#{base_path}/#{pack.fetch("id")}.json", params: { enabled: false }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("node_pack", "enabled")).to eq(false)

    get "#{base_path}/#{pack.fetch("id")}/export.json"
    expect(response).to have_http_status(:ok)
    expect(response.headers["Content-Disposition"]).to include("jev-1.0.0.json")
    expect(response.body).not_to include("secret")

    delete "#{base_path}/#{pack.fetch("id")}.json"
    expect(response).to have_http_status(:no_content)
    expect(DiscourseWorkflows::NodePack.find(pack.fetch("id"))).to be_removed_at
    expect(
      DiscourseWorkflows::NodePackDefinition.where(node_pack_id: pack.fetch("id")).count,
    ).to eq(4)
  end

  it "serves HTML routes without shadowing JSON endpoints" do
    get base_path
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/html")

    get "#{base_path}.json"
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/json")
  end

  it "returns typed validation and approval failures" do
    post "#{base_path}.json", params: { manifest:, approved_destinations: [] }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body).to include(
      "type" => "destinations_not_approved",
      "missing" => ["https://api.typesafe.ai"],
    )

    post "#{base_path}/preview.json", params: { manifest: "{}" }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body["type"]).to eq("invalid_manifest")
    expect(response.parsed_body["errors"]).not_to be_empty
  end

  it "is hidden from non-admin users" do
    sign_in(user)
    get "#{base_path}.json"
    expect(response).to have_http_status(:not_found)
  end
end
