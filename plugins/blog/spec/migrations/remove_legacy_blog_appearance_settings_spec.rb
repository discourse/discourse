# frozen_string_literal: true

require Rails.root.join(
          "plugins/blog/db/migrate/20260915045302_remove_legacy_blog_appearance_settings.rb",
        )

RSpec.describe RemoveLegacyBlogAppearanceSettings do
  fab!(:admin)

  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    PluginStoreRow.where(plugin_name: "discourse-blog-themes").delete_all
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  def set_legacy(name, value)
    DB.exec(<<~SQL, name: name, value: value)
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      VALUES (:name, 1, :value, NOW(), NOW())
    SQL
  end

  def legacy_rows
    DB.query_single(<<~SQL).first.to_i
      SELECT COUNT(*) FROM site_settings
      WHERE name IN (
        'discourse_blog_accent_color',
        'discourse_blog_paper_color',
        'discourse_blog_ink_color',
        'discourse_blog_custom_css',
        'discourse_blog_custom_js'
      )
    SQL
  end

  it "keeps a settings-only design as an activated theme, then removes the settings" do
    allow(Migration::Helpers).to receive(:existing_site?).and_return(true)
    set_legacy("discourse_blog_accent_color", "bc4327")
    set_legacy("discourse_blog_custom_css", ".blog { color: red; }")
    set_legacy("discourse_blog_custom_js", "window.blogDemo = true;")

    described_class.new.up

    theme = Blog::BlogTheme.active
    expect(theme["accent_color"]).to eq("bc4327")
    expect(theme["css"]).to eq(".blog { color: red; }")
    expect(theme["javascript"]).to eq("window.blogDemo = true;")
    expect(theme["paper_color"]).to eq("f5f0e6")
    expect(theme["ink_color"]).to eq("19382d")
    expect(Blog::BlogTheme.all.size).to eq(1)
    expect(Blog::BlogTheme.snapshot(theme["snapshot"])).to be_present
    expect(legacy_rows).to eq(0)
  end

  it "adds no theme when the settings still hold the built-in design" do
    allow(Migration::Helpers).to receive(:existing_site?).and_return(true)
    set_legacy("discourse_blog_accent_color", "d64b2a")

    described_class.new.up

    expect(Blog::BlogTheme.all).to be_empty
    expect(legacy_rows).to eq(0)
  end

  it "leaves a site that already has themes untouched" do
    allow(Migration::Helpers).to receive(:existing_site?).and_return(true)
    saved =
      Blog::BlogTheme.save(
        {
          "name" => "Saved design",
          "accent_color" => "16634e",
          "paper_color" => "fcfcfa",
          "ink_color" => "222b28",
          "css" => "",
          "javascript" => "",
        },
        user: admin,
      )
    Blog::BlogTheme.activate(saved["id"], revision: 1, user: admin)
    set_legacy("discourse_blog_custom_css", ".blog { color: red; }")

    described_class.new.up

    expect(Blog::BlogTheme.all.size).to eq(1)
    expect(Blog::BlogTheme.active["accent_color"]).to eq("16634e")
    expect(legacy_rows).to eq(0)
  end

  it "writes nothing on a fresh install" do
    allow(Migration::Helpers).to receive(:existing_site?).and_return(false)
    set_legacy("discourse_blog_accent_color", "bc4327")

    described_class.new.up

    expect(Blog::BlogTheme.all).to be_empty
    expect(PluginStoreRow.where(plugin_name: "discourse-blog-themes").count).to eq(0)
    expect(legacy_rows).to eq(0)
  end
end
