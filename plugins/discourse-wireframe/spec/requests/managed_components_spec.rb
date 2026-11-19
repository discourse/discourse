# frozen_string_literal: true

RSpec.describe "Managed layout components" do
  fab!(:admin)
  fab!(:parent) { Fabricate(:theme, name: "Parent") }
  fab!(:layout_component) { Fabricate(:theme, name: "A layout", component: true) }
  fab!(:plain) { Fabricate(:theme, name: "A plain component", component: true) }

  before do
    Theme::ManagedComponentIds.reset
    SiteSetting.wireframe_enabled = true
    DiscourseWireframe::BlockLayoutCompanion.create!(
      parent_theme_id: parent.id,
      component_theme_id: layout_component.id,
    )
    sign_in(admin)
  end

  it "hides layouts from the components list" do
    get "/admin/config/customize/components.json"

    names = response.parsed_body["components"].map { _1["name"] }
    expect(names).to include("A plain component")
    expect(names).not_to include("A layout")
  end

  it "keeps an installed layout attached when the components input is saved" do
    parent.add_relative_theme!(:child, layout_component)

    put "/admin/themes/#{parent.id}.json", params: { theme: { child_theme_ids: [plain.id] } }

    expect(response.status).to eq(200)
    expect(parent.reload.child_theme_ids).to contain_exactly(layout_component.id, plain.id)
  end
end
