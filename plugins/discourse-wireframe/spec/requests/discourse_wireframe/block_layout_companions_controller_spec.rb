# frozen_string_literal: true

RSpec.describe DiscourseWireframe::BlockLayoutCompanionsController do
  fab!(:admin)
  fab!(:user)
  fab!(:parent) { Fabricate(:theme_with_remote_url, name: "Acme") }

  before { SiteSetting.wireframe_enabled = true }

  let(:layout_json) do
    { schema_version: 1, layout: [{ block: "hero-banner", args: { title: "Hi" } }] }.to_json
  end
  let(:drafts) { [{ outlet_name: "homepage-blocks", layout_json: layout_json }] }

  describe "POST #create" do
    it "creates the companion, records the mapping, and returns its theme id" do
      sign_in(admin)
      expect {
        post "/admin/plugins/wireframe/customization-component.json",
             params: {
               theme_id: parent.id,
               name: "Spring launch",
               drafts: drafts,
             }
      }.to change { Theme.count }.by(1)

      expect(response.status).to eq(200)
      component_id = response.parsed_body["theme_id"]
      expect(parent.reload.child_theme_ids).to include(component_id)
      expect(DiscourseWireframe::BlockLayoutCompanion.companion_id_for(parent.id)).to eq(
        component_id,
      )
    end

    it "accepts drafts posted as a positional hash (the browser's array encoding)" do
      sign_in(admin)
      post "/admin/plugins/wireframe/customization-component.json",
           params: {
             theme_id: parent.id,
             name: "Spring launch",
             drafts: {
               "0" => {
                 outlet_name: "homepage-blocks",
                 layout_json: layout_json,
               },
             },
           }
      expect(response.status).to eq(200)
      component = Theme.find(response.parsed_body["theme_id"])
      expect(
        component.theme_fields.find_by(
          name: "homepage-blocks",
          type_id: ThemeField.types[:block_layout],
        ),
      ).to be_present
    end

    it "returns 404 for a non-admin" do
      sign_in(user)
      post "/admin/plugins/wireframe/customization-component.json",
           params: {
             theme_id: parent.id,
             name: "Spring launch",
             drafts: drafts,
           }
      expect(response.status).to eq(404)
    end
  end

  describe "PUT #update" do
    it "installs another design and unlinks the current one" do
      sign_in(admin)
      post "/admin/plugins/wireframe/customization-component.json",
           params: {
             theme_id: parent.id,
             name: "First",
             drafts: drafts,
           }
      first_id = response.parsed_body["theme_id"]
      post "/admin/plugins/wireframe/customization-component.json",
           params: {
             theme_id: parent.id,
             name: "Second",
             drafts: drafts,
           }
      second_id = response.parsed_body["theme_id"]

      put "/admin/plugins/wireframe/companion.json",
          params: {
            theme_id: parent.id,
            design_id: first_id,
          }

      expect(response.status).to eq(200)
      expect(parent.reload.child_theme_ids).to contain_exactly(first_id)
      get "/admin/plugins/wireframe/companion.json", params: { theme_id: parent.id }
      expect(response.parsed_body["designs"]).to eq(
        [
          { "id" => second_id, "name" => "Second", "active" => false },
          { "id" => first_id, "name" => "First", "active" => true },
        ],
      )
    end

    it "404s for a theme that is not one of the parent's designs" do
      sign_in(admin)
      put "/admin/plugins/wireframe/companion.json",
          params: {
            theme_id: parent.id,
            design_id: Fabricate(:theme, component: true).id,
          }
      expect(response.status).to eq(404)
    end
  end

  describe "GET #index" do
    it "lists every design with its theme and whether it is in use" do
      sign_in(admin)
      %w[First Second].each do |name|
        post "/admin/plugins/wireframe/customization-component.json",
             params: {
               theme_id: parent.id,
               name: name,
               drafts: drafts,
             }
      end

      get "/admin/plugins/wireframe/designs.json"

      expect(response.status).to eq(200)
      expect(
        response.parsed_body["designs"].map do
          _1.slice("name", "theme_id", "theme_name", "active")
        end,
      ).to eq(
        [
          { "name" => "Second", "theme_id" => parent.id, "theme_name" => "Acme", "active" => true },
          { "name" => "First", "theme_id" => parent.id, "theme_name" => "Acme", "active" => false },
        ],
      )
    end

    it "returns 404 for a non-admin" do
      sign_in(user)
      get "/admin/plugins/wireframe/designs.json"
      expect(response.status).to eq(404)
    end
  end

  describe "GET #design" do
    it "returns the design with its published layouts and version tokens" do
      sign_in(admin)
      post "/admin/plugins/wireframe/customization-component.json",
           params: {
             theme_id: parent.id,
             name: "Spring launch",
             drafts: drafts,
           }
      design_id = response.parsed_body["theme_id"]

      get "/admin/plugins/wireframe/designs/#{design_id}.json"

      expect(response.status).to eq(200)
      body = response.parsed_body
      expect(body.slice("id", "name", "theme_id", "active")).to eq(
        "id" => design_id,
        "name" => "Spring launch",
        "theme_id" => parent.id,
        "active" => true,
      )
      expect(body["layouts"].map { _1["outlet"] }).to eq(["homepage-blocks"])
      expect(body["layouts"].first["layout"].first["block"]).to eq("hero-banner")
      expect(body["layouts"].first["version_token"]).to be_present
    end

    it "404s for a theme that isn't a design" do
      sign_in(admin)
      get "/admin/plugins/wireframe/designs/#{parent.id}.json"
      expect(response.status).to eq(404)
    end
  end

  describe "DELETE #destroy" do
    it "deletes the design and 204s" do
      sign_in(admin)
      post "/admin/plugins/wireframe/customization-component.json",
           params: {
             theme_id: parent.id,
             name: "Spring launch",
             drafts: drafts,
           }
      design_id = response.parsed_body["theme_id"]

      delete "/admin/plugins/wireframe/companion.json",
             params: {
               theme_id: parent.id,
               design_id: design_id,
             }

      expect(response.status).to eq(204)
      expect(Theme.exists?(design_id)).to eq(false)
    end

    it "404s for a theme that is not one of the parent's designs" do
      sign_in(admin)
      delete "/admin/plugins/wireframe/companion.json",
             params: {
               theme_id: parent.id,
               design_id: Fabricate(:theme, component: true).id,
             }
      expect(response.status).to eq(404)
    end
  end

  describe "GET #show" do
    it "returns the companion id once one exists, and null otherwise" do
      sign_in(admin)

      get "/admin/plugins/wireframe/companion.json", params: { theme_id: parent.id }
      expect(response.status).to eq(200)
      expect(response.parsed_body["companion_id"]).to be_nil

      post "/admin/plugins/wireframe/customization-component.json",
           params: {
             theme_id: parent.id,
             name: "Spring launch",
             drafts: drafts,
           }
      component_id = response.parsed_body["theme_id"]

      get "/admin/plugins/wireframe/companion.json", params: { theme_id: parent.id }
      expect(response.parsed_body["companion_id"]).to eq(component_id)
    end

    it "still resolves the companion after it is renamed" do
      sign_in(admin)
      post "/admin/plugins/wireframe/customization-component.json",
           params: {
             theme_id: parent.id,
             name: "Spring launch",
             drafts: drafts,
           }
      component_id = response.parsed_body["theme_id"]
      Theme.find(component_id).update!(name: "Renamed companion")

      get "/admin/plugins/wireframe/companion.json", params: { theme_id: parent.id }
      expect(response.parsed_body["companion_id"]).to eq(component_id)
    end

    it "returns 404 for a non-admin" do
      sign_in(user)
      get "/admin/plugins/wireframe/companion.json", params: { theme_id: parent.id }
      expect(response.status).to eq(404)
    end
  end
end
