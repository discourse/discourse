# frozen_string_literal: true

# Plugins can register an icon set too (see Plugin::Instance#register_icon_set):
# same declaration shape as a theme's about.json icon_set, with the plugin's
# svg-icons sprite as the glyph source and {placeholder} tokens resolving from
# same-named site settings.
RSpec.describe SvgSprite do
  fab!(:theme)

  before { allow(Rails.env).to receive(:test?).and_return(false) }

  after do
    SvgSprite.expire_cache
    SvgSprite.clear_plugin_svg_sprite_cache!
    Theme.clear_cache!
  end

  def plugin_sprite
    SvgSprite.symbols_for(
      "phosphor-multiweight-sprite.svg",
      file_from_fixtures("phosphor-multiweight-sprite.svg").read,
      strict: false,
    )
  end

  def register_plugin_set!(map:, plugin_name: "fake-icons", **registration)
    allow(DiscoursePluginRegistry).to receive(:icon_sets).and_return(
      [{ map: map, plugin_name: plugin_name, plugin_dir: "/tmp", **registration }],
    )
    allow(SvgSprite).to receive(:plugin_svgs_by_plugin).and_return(plugin_name => plugin_sprite)
  end

  it "aliases the plugin set onto canonical ids and drops its raw glyph ids" do
    register_plugin_set!(map: { "bell" => "ph-regular-bell" })
    bundle = SvgSprite.bundle(theme.id)

    expect(bundle[%r{<symbol id="bell".*?</symbol>}m]).to include("M128 24a8") # Phosphor bell
    expect(bundle).not_to include("ph-regular-bell")
    expect(bundle).not_to include("ph-bold-bell") # unused variants dropped
    expect(SvgSprite.all_icons(theme.id)).not_to include("ph-regular-bell")
  end

  it "applies the plugin set with no theme too" do
    register_plugin_set!(map: { "bell" => "ph-regular-bell" })
    expect(SvgSprite.bundle(nil)[%r{<symbol id="bell".*?</symbol>}m]).to include("M128 24a8")
  end

  it "resolves {placeholder} tokens from same-named site settings" do
    SiteSetting.title = "bold"
    register_plugin_set!(map: { "bell" => "ph-{title}-bell" })

    expect(SvgSprite.bundle(theme.id)[%r{<symbol id="bell".*?</symbol>}m]).to include("M128 16a16")
  end

  it "keeps the default glyph for icons listed in the ignore site setting" do
    SiteSetting.svg_icon_subset = "bell"
    register_plugin_set!(
      map: {
        "bell" => "ph-regular-bell",
        "gear" => "ph-regular-gear",
      },
      ignore_setting: "svg_icon_subset",
    )

    bundle = SvgSprite.bundle(theme.id)
    expect(bundle[%r{<symbol id="bell".*?</symbol>}m]).not_to include("M128 24a8") # FA kept
    expect(bundle[%r{<symbol id="gear".*?</symbol>}m]).to include("M128 80a48") # still aliased
  end

  it "normalizes idiomatic Symbol registrations (map keys and ignore_setting)" do
    SiteSetting.svg_icon_subset = "gear"
    register_plugin_set!(
      map: {
        bell: "ph-regular-bell",
        gear: "ph-regular-gear",
      },
      ignore_setting: :svg_icon_subset,
    )

    bundle = SvgSprite.bundle(theme.id)
    expect(bundle[%r{<symbol id="bell".*?</symbol>}m]).to include("M128 24a8") # symbol key aliased
    expect(bundle[%r{<symbol id="gear".*?</symbol>}m]).not_to include("M128 80a48") # symbol ignore honored
  end

  it "is overridden by a theme-declared icon set" do
    register_plugin_set!(map: { "bell" => "ph-regular-bell" })

    fname = "phosphor-multiweight-sprite.svg"
    upload = UploadCreator.new(file_from_fixtures(fname), fname, for_theme: true).create_for(-1)
    theme.set_field(
      target: :common,
      name: SvgSprite.theme_sprite_variable_name,
      upload_id: upload.id,
      type: :theme_upload_var,
    )
    theme.set_field(
      target: :common,
      name: SvgSprite::ICON_SET_FIELD_NAME,
      type: :json,
      value: { "map" => { "bell" => "ph-bold-bell" } }.to_json,
    )
    theme.save!

    bell = SvgSprite.bundle(theme.id)[%r{<symbol id="bell".*?</symbol>}m]
    expect(bell).to include("M128 16a16") # the theme's choice (bold), not the plugin's
  end

  it "reads the map from a JSON file inside the plugin directory only" do
    Dir.mktmpdir do |dir|
      File.write("#{dir}/icon-map.json", { "bell" => "ph-regular-bell" }.to_json)

      registered = { map: "icon-map.json", plugin_dir: dir, plugin_name: "fake-icons" }
      expect(SvgSprite.build_plugin_icon_set([registered])["map"]).to eq(
        "bell" => "ph-regular-bell",
      )

      escaping = { map: "../outside.json", plugin_dir: dir, plugin_name: "fake-icons" }
      expect(SvgSprite.build_plugin_icon_set([escaping])).to be_nil
    end
  end

  it "identifies site settings that affect a registered set (cache expiry gate)" do
    SvgSprite.clear_plugin_svg_sprite_cache! # the affected-settings set is memoized
    plugin = instance_double(Plugin::Instance, enabled_site_setting: :fake_icons_enabled)
    allow(DiscoursePluginRegistry).to receive(:_raw_icon_sets).and_return(
      [
        {
          plugin: plugin,
          value: {
            map: {
              "bell" => "ph-{fake_icons_weight}-bell",
            },
            ignore_setting: "fake_icons_ignored",
          },
        },
      ],
    )

    expect(SvgSprite.icon_set_site_setting?(:fake_icons_weight)).to eq(true)
    expect(SvgSprite.icon_set_site_setting?(:fake_icons_enabled)).to eq(true)
    expect(SvgSprite.icon_set_site_setting?(:fake_icons_ignored)).to eq(true)
    expect(SvgSprite.icon_set_site_setting?(:title)).to eq(false)
  end
end
