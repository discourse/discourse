# frozen_string_literal: true

RSpec.describe Admin::BlockLayoutsController do
  fab!(:admin)
  fab!(:user)
  fab!(:theme)

  let(:layout_json) do
    { schema_version: 1, layout: [{ block: "hero-banner", args: { title: "Hi" } }] }.to_json
  end

  def live_field(theme)
    theme.theme_fields.find_by(name: "homepage-blocks", type_id: ThemeField.types[:block_layout])
  end

  describe "POST #publish" do
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

      it "publishes a block_layout field and returns a version token" do
        post "/admin/customize/block-layouts.json",
             params: {
               theme_id: theme.id,
               outlet_name: "homepage-blocks",
               layout_json: layout_json,
             }

        expect(response.status).to eq(200)
        body = response.parsed_body
        expect(body["success"]).to eq(true)
        expect(body["theme_id"]).to eq(theme.id)
        expect(body["version_token"]).to be_present
        expect(live_field(theme)).to be_present
      end

      it "succeeds on a first publish with an empty expected token" do
        post "/admin/customize/block-layouts.json",
             params: {
               theme_id: theme.id,
               outlet_name: "homepage-blocks",
               layout_json: layout_json,
               expected_version_token: "",
             }
        expect(response.status).to eq(200)
      end

      it "returns 409 when the expected token is stale" do
        post "/admin/customize/block-layouts.json",
             params: {
               theme_id: theme.id,
               outlet_name: "homepage-blocks",
               layout_json: layout_json,
             }

        post "/admin/customize/block-layouts.json",
             params: {
               theme_id: theme.id,
               outlet_name: "homepage-blocks",
               layout_json: layout_json,
               expected_version_token: "stale-token",
             }
        expect(response.status).to eq(409)
      end

      it "returns 422 for a Git-imported theme (publish disabled)" do
        git_theme = Fabricate(:theme_with_remote_url)

        post "/admin/customize/block-layouts.json",
             params: {
               theme_id: git_theme.id,
               outlet_name: "homepage-blocks",
               layout_json: layout_json,
             }
        expect(response.status).to eq(422)
        expect(live_field(git_theme)).to be_nil
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

  describe "DELETE #destroy (reset to default)" do
    before { sign_in(admin) }

    it "deletes the live field and returns success" do
      theme.set_field(
        target: :common,
        name: "homepage-blocks",
        type: :block_layout,
        value: layout_json,
      )
      theme.save!
      expect(live_field(theme)).to be_present

      delete "/admin/customize/block-layouts.json",
             params: {
               theme_id: theme.id,
               outlet_name: "homepage-blocks",
             }

      expect(response.status).to eq(200)
      expect(live_field(theme)).to be_nil
    end
  end
end
