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
             drafts: drafts,
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
