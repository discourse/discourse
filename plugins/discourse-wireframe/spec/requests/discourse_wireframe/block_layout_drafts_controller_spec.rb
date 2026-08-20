# frozen_string_literal: true

RSpec.describe DiscourseWireframe::BlockLayoutDraftsController do
  fab!(:admin)
  fab!(:user)
  fab!(:theme)

  before { SiteSetting.wireframe_enabled = true }

  let(:layout_json) do
    { schema_version: 1, layout: [{ block: "hero-banner", args: { title: "Hi" } }] }.to_json
  end

  def drafts
    DiscourseWireframe::BlockLayoutDraft.where(user: admin, theme: theme, outlet: "homepage-blocks")
  end

  def live_field
    theme.theme_fields.find_by(name: "homepage-blocks", type_id: ThemeField.types[:block_layout])
  end

  it "saves and discards a private draft for an admin" do
    sign_in(admin)

    post "/admin/plugins/wireframe/block-layout-drafts.json",
         params: {
           theme_id: theme.id,
           outlet_name: "homepage-blocks",
           layout_json: layout_json,
         }
    expect(response.status).to eq(200)
    expect(drafts.count).to eq(1)
    # A draft is never the live field.
    expect(live_field).to be_nil

    delete "/admin/plugins/wireframe/block-layout-drafts.json",
           params: {
             theme_id: theme.id,
             outlet_name: "homepage-blocks",
           }
    expect(response.status).to eq(200)
    expect(drafts.count).to eq(0)
  end

  it "returns 404 for a non-admin saving a draft" do
    sign_in(user)

    post "/admin/plugins/wireframe/block-layout-drafts.json",
         params: {
           theme_id: theme.id,
           outlet_name: "homepage-blocks",
           layout_json: layout_json,
         }
    expect(response.status).to eq(404)
  end

  describe "#index" do
    fab!(:other_theme, :theme)

    it "returns only the current admin's own drafts, scoped to the requested themes" do
      DiscourseWireframe::BlockLayoutDraft.create!(
        user: admin,
        theme: theme,
        outlet: "homepage-blocks",
        data: layout_json,
        base_version_token: "t1",
      )
      # Another user's draft and a draft on an unrequested theme must not leak.
      DiscourseWireframe::BlockLayoutDraft.create!(
        user: user,
        theme: theme,
        outlet: "homepage-blocks",
        data: layout_json,
      )
      DiscourseWireframe::BlockLayoutDraft.create!(
        user: admin,
        theme: other_theme,
        outlet: "sidebar-blocks",
        data: layout_json,
      )

      sign_in(admin)
      get "/admin/plugins/wireframe/block-layout-drafts.json", params: { theme_ids: [theme.id] }

      expect(response.status).to eq(200)
      returned = response.parsed_body["drafts"]
      expect(returned.size).to eq(1)
      expect(returned.first).to include(
        "theme_id" => theme.id,
        "outlet" => "homepage-blocks",
        "data" => layout_json,
        "base_version_token" => "t1",
      )
    end

    it "returns 404 for a non-admin" do
      sign_in(user)
      get "/admin/plugins/wireframe/block-layout-drafts.json"
      expect(response.status).to eq(404)
    end
  end
end
