# frozen_string_literal: true

RSpec.describe ApplicationLayoutPreloader do
  fab!(:guardian) { Guardian.new }

  def build_preloader(theme_id: nil)
    described_class.new(
      guardian: guardian,
      theme_id: theme_id,
      theme_target: :common,
      login_method: nil,
    )
  end

  describe "themeBlockLayouts preloaded entry" do
    fab!(:theme)
    fab!(:component_theme) { Fabricate(:theme, component: true, name: "side-effects") }

    let(:layout_for_homepage) do
      { schema_version: 1, layout: [{ block: "hero-banner", args: { title: "Welcome" } }] }.to_json
    end

    let(:layout_for_sidebar) { { schema_version: 1, layout: [{ block: "tag-cloud" }] }.to_json }

    def preloaded_block_layouts(theme_id:)
      preloader = build_preloader(theme_id: theme_id)
      JSON.parse(preloader.preloaded_data["themeBlockLayouts"])
    end

    it "is an empty array when no theme is active" do
      expect(preloaded_block_layouts(theme_id: nil)).to eq([])
    end

    it "is an empty array when the active theme has no block_layout fields" do
      expect(preloaded_block_layouts(theme_id: theme.id)).to eq([])
    end

    it "exposes block_layout fields for the resolved theme stack" do
      theme.set_field(
        target: :common,
        name: "homepage-blocks",
        type: :block_layout,
        value: layout_for_homepage,
      )
      theme.set_field(
        target: :common,
        name: "sidebar-blocks",
        type: :block_layout,
        value: layout_for_sidebar,
      )
      theme.save!

      payload = preloaded_block_layouts(theme_id: theme.id)

      expect(payload.map { |r| r["outlet"] }).to contain_exactly(
        "homepage-blocks",
        "sidebar-blocks",
      )
      payload.each do |row|
        expect(row["theme_id"]).to eq(theme.id)
        expect(row["schema_version"]).to eq(1)
        expect(row["layout"]).to be_an(Array)
      end
    end

    it "orders themes by stack position so the last theme tails its outlet's entry" do
      theme.add_relative_theme!(:child, component_theme)
      theme.set_field(
        target: :common,
        name: "homepage-blocks",
        type: :block_layout,
        value: { schema_version: 1, layout: [{ block: "first" }] }.to_json,
      )
      component_theme.set_field(
        target: :common,
        name: "homepage-blocks",
        type: :block_layout,
        value: { schema_version: 1, layout: [{ block: "second" }] }.to_json,
      )
      theme.save!
      component_theme.save!

      payload = preloaded_block_layouts(theme_id: theme.id)
      stack_order = Theme.transform_ids(theme.id)

      expect(payload.length).to eq(2)
      expect(payload.map { |r| r["theme_id"] }).to eq(stack_order)
    end

    it "skips fields that failed to bake" do
      theme.set_field(
        target: :common,
        name: "homepage-blocks",
        type: :block_layout,
        value: "{not valid",
      )
      theme.save!

      expect(preloaded_block_layouts(theme_id: theme.id)).to eq([])
    end
  end

  describe "themeBlockLayoutMeta preloaded entry" do
    fab!(:theme)
    fab!(:component_theme) { Fabricate(:theme, component: true, name: "side-effects") }

    def preloaded_meta(theme_id:)
      preloader = build_preloader(theme_id: theme_id)
      JSON.parse(preloader.preloaded_data["themeBlockLayoutMeta"])
    end

    it "is an empty object when no theme is active" do
      expect(preloaded_meta(theme_id: nil)).to eq({})
    end

    it "carries name, component, is_git and stack_index per theme in stack order" do
      theme.add_relative_theme!(:child, component_theme)

      meta = preloaded_meta(theme_id: theme.id)
      stack_order = Theme.transform_ids(theme.id)

      # stack_index matches the theme's position in transform_ids (parent first).
      stack_order.each_with_index { |id, index| expect(meta[id.to_s]["stack_index"]).to eq(index) }

      parent = meta[theme.id.to_s]
      expect(parent["name"]).to eq(theme.name)
      expect(parent["component"]).to eq(false)
      expect(parent["is_git"]).to eq(false)

      expect(meta[component_theme.id.to_s]["component"]).to eq(true)
    end

    it "marks a theme installed from a remote (git) source" do
      git_theme = Fabricate(:theme_with_remote_url)

      meta = preloaded_meta(theme_id: git_theme.id)
      expect(meta[git_theme.id.to_s]["is_git"]).to eq(true)
    end

    it "treats a locally-imported theme (remote_theme with a blank URL) as not git" do
      # A zip/dir-imported theme (e.g. an editable duplicate) has a remote_theme
      # record but a blank remote_url — it is editable, not Git-managed.
      local_import = Fabricate(:theme)
      local_import.update!(remote_theme: RemoteTheme.create!(remote_url: ""))

      meta = preloaded_meta(theme_id: local_import.id)
      expect(meta[local_import.id.to_s]["is_git"]).to eq(false)
    end
  end
end
