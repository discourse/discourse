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
        # The conflict body carries the live version + publish time so the
        # client can reconcile (overwrite against the current version).
        live =
          theme.theme_fields.find_by(
            name: "homepage-blocks",
            type_id: ThemeField.types[:block_layout],
          )
        expect(response.parsed_body["current_version"]).to eq(
          Themes::BlockLayoutVersion.token_for(live.value_baked),
        )
        expect(response.parsed_body["published_at"]).to be_present
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

  describe "POST #export" do
    before do
      theme.set_field(
        target: :common,
        name: "homepage-blocks",
        type: :block_layout,
        value: layout_json,
      )
      theme.save!
    end

    context "as an admin" do
      before { sign_in(admin) }

      it "returns the canonical filename and parseable content" do
        post "/admin/customize/block-layouts/export.json",
             params: {
               theme_id: theme.id,
               outlet_name: "homepage-blocks",
             }

        expect(response.status).to eq(200)
        body = response.parsed_body
        expect(body["filename"]).to eq("block_layouts/homepage-blocks.json")
        parsed = JSON.parse(body["content"])
        expect(parsed["schema_version"]).to eq(1)
        expect(parsed["layout"].first["block"]).to eq("hero-banner")
      end

      it "produces a filename the importer reverses to the same outlet" do
        post "/admin/customize/block-layouts/export.json",
             params: {
               theme_id: theme.id,
               outlet_name: "homepage-blocks",
             }
        exported = response.parsed_body

        # The export filename must round-trip through the import path matcher
        # back to the original outlet name + target + type.
        opts = ThemeField.opts_from_file_path(exported["filename"])
        expect(opts).to include(name: "homepage-blocks", target: :common, type: :block_layout)

        # And a field set from the exported content holds the same layout.
        importer = Fabricate(:theme)
        importer.set_field(value: exported["content"], **opts)
        importer.save!
        field =
          importer.theme_fields.find_by(
            name: "homepage-blocks",
            type_id: ThemeField.types[:block_layout],
          )
        expect(field).to be_present
        expect(JSON.parse(field.value)["layout"].first["block"]).to eq("hero-banner")
      end

      it "exports a layout_json override without a live field" do
        override = {
          schema_version: 1,
          layout: [{ block: "hero-banner", args: { title: "Draft" } }],
        }.to_json
        post "/admin/customize/block-layouts/export.json",
             params: {
               theme_id: theme.id,
               outlet_name: "sidebar-blocks",
               layout_json: override,
             }

        expect(response.status).to eq(200)
        expect(JSON.parse(response.parsed_body["content"])["layout"].first["args"]["title"]).to eq(
          "Draft",
        )
      end

      it "returns 404 when there is no field and no override" do
        post "/admin/customize/block-layouts/export.json",
             params: {
               theme_id: theme.id,
               outlet_name: "sidebar-blocks",
             }
        expect(response.status).to eq(404)
      end

      it "returns 422 for a malformed override" do
        post "/admin/customize/block-layouts/export.json",
             params: {
               theme_id: theme.id,
               outlet_name: "homepage-blocks",
               layout_json: "{not json",
             }
        expect(response.status).to eq(422)
      end
    end

    it "returns 404 for a non-admin" do
      sign_in(user)
      post "/admin/customize/block-layouts/export.json",
           params: {
             theme_id: theme.id,
             outlet_name: "homepage-blocks",
           }
      expect(response.status).to eq(404)
    end
  end

  describe "POST #duplicate" do
    fab!(:git_theme) { Fabricate(:theme_with_remote_url, name: "Acme") }
    let(:drafts) { [{ outlet_name: "homepage-blocks", layout_json: layout_json }] }

    context "as an admin" do
      before { sign_in(admin) }

      it "creates an editable copy and returns its id" do
        expect {
          post "/admin/customize/block-layouts/duplicate.json",
               params: {
                 theme_id: git_theme.id,
                 drafts: drafts,
               }
        }.to change { Theme.count }.by(1)

        expect(response.status).to eq(200)
        copy = Theme.find(response.parsed_body["theme_id"])
        expect(copy.remote_theme&.is_git?).to be_falsey
        expect(
          copy.theme_fields.exists?(
            name: "homepage-blocks",
            type_id: ThemeField.types[:block_layout],
          ),
        ).to eq(true)
      end

      it "returns 422 when the theme opts out of duplication" do
        git_theme.theme_modifier_set.update!(duplicable_theme: false)
        post "/admin/customize/block-layouts/duplicate.json",
             params: {
               theme_id: git_theme.id,
               drafts: drafts,
             }
        expect(response.status).to eq(422)
      end

      it "returns 422 for a malformed draft" do
        post "/admin/customize/block-layouts/duplicate.json",
             params: {
               theme_id: git_theme.id,
               drafts: [{ outlet_name: "homepage-blocks", layout_json: "{not json" }],
             }
        expect(response.status).to eq(422)
      end
    end

    it "returns 404 for a non-admin" do
      sign_in(user)
      post "/admin/customize/block-layouts/duplicate.json",
           params: {
             theme_id: git_theme.id,
             drafts: drafts,
           }
      expect(response.status).to eq(404)
    end
  end
end
