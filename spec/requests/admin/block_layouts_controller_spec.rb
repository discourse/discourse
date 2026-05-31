# frozen_string_literal: true

RSpec.describe Admin::BlockLayoutsController do
  fab!(:admin)
  fab!(:user)
  fab!(:theme)

  let(:layout_json) do
    { schema_version: 1, layout: [{ block: "hero-banner", args: { title: "Hi" } }] }.to_json
  end

  describe "POST #create" do
    context "as a non-admin" do
      before { sign_in(user) }

      it "returns 404 (admin-only)" do
        post "/admin/customize/block-layouts.json",
             params: {
               theme_id: theme.id,
               outlet_name: "homepage-blocks",
               layout_json: layout_json,
             }
        expect(response.status).to eq(404)
      end
    end

    context "as an admin" do
      before { sign_in(admin) }

      it "saves a block_layout field on the target theme" do
        post "/admin/customize/block-layouts.json",
             params: {
               theme_id: theme.id,
               outlet_name: "homepage-blocks",
               layout_json: layout_json,
             }

        expect(response.status).to eq(200)
        body = response.parsed_body
        expect(body["success"]).to eq(true)
        expect(body["target_theme_id"]).to eq(theme.id)
        expect(body["redirected"]).to eq(false)

        field =
          theme.theme_fields.find_by(
            name: "homepage-blocks",
            type_id: ThemeField.types[:block_layout],
          )
        expect(field).to be_present
      end

      it "redirects to a child component for Git-imported themes" do
        git_theme = Fabricate(:theme_with_remote_url)

        post "/admin/customize/block-layouts.json",
             params: {
               theme_id: git_theme.id,
               outlet_name: "homepage-blocks",
               layout_json: layout_json,
             }

        expect(response.status).to eq(200)
        body = response.parsed_body
        expect(body["redirected"]).to eq(true)
        expect(body["child_created"]).to eq(true)
        expect(body["target_theme_name"]).to eq("#{git_theme.name}-customizations")
      end

      it "returns 404 when the theme doesn't exist" do
        post "/admin/customize/block-layouts.json",
             params: {
               theme_id: 999_999,
               outlet_name: "homepage-blocks",
               layout_json: layout_json,
             }
        expect(response.status).to eq(404)
      end

      it "returns 422 when the layout fails to bake" do
        post "/admin/customize/block-layouts.json",
             params: {
               theme_id: theme.id,
               outlet_name: "homepage-blocks",
               layout_json: { schema_version: 99, layout: [] }.to_json,
             }
        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"].join).to match(
          /Unsupported block_layout schema_version/,
        )
      end

      it "returns 400 when params are invalid" do
        post "/admin/customize/block-layouts.json",
             params: {
               theme_id: theme.id,
               outlet_name: "",
               layout_json: layout_json,
             }
        expect(response.status).to eq(400)
      end
    end
  end
end
