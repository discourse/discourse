# frozen_string_literal: true

# First-class "icon set": a theme declares a map of canonical icon names -> its
# sprite's glyph ids (optionally weight-templated). The bundler aliases the set
# glyph onto the canonical id, so no client-side replaceIcon is needed and only
# the rendered set ships (no replaced-FA dead weight, no unused weight variants).
RSpec.describe SvgSprite do
  fab!(:theme)

  before { allow(Rails.env).to receive(:test?).and_return(false) }

  after do
    SvgSprite.expire_cache
    Theme.clear_cache!
  end

  let(:default_map) do
    { "bell" => "ph-{weight}-bell", "gear" => "ph-{weight}-gear", "flask" => "ph-{weight}-flask" }
  end

  def add_sprite!(target_theme, fname)
    upload = UploadCreator.new(file_from_fixtures(fname), fname, for_theme: true).create_for(-1)
    target_theme.set_field(
      target: :common,
      name: SvgSprite.theme_sprite_variable_name,
      upload_id: upload.id,
      type: :theme_upload_var,
    )
  end

  # A real set maps the vast majority of icons; only a genuine remainder with no
  # equivalent (brand logos like fab-wikipedia-w, etc.) falls back to Font Awesome.
  # This fixture maps a few common icons to exercise aliasing + fallback honestly.
  def declare_icon_set!(weight: "regular", map: default_map, sprite: true)
    add_sprite!(theme, "phosphor-multiweight-sprite.svg") if sprite
    theme.set_field(target: :settings, name: :yaml, value: <<~YAML)
      weight: #{weight}
      ignored_icons:
        type: list
        default: ""
    YAML
    theme.set_field(
      target: :common,
      name: SvgSprite::ICON_SET_FIELD_NAME,
      type: :json,
      value: { "map" => map }.to_json,
    )
    theme.save!
  end

  it "aliases mapped icons onto canonical ids; only the genuine remainder is Font Awesome" do
    declare_icon_set!(weight: "regular")
    bundle = SvgSprite.bundle(theme.id)

    bell = bundle[%r{<symbol id="bell".*?</symbol>}m]
    expect(bell).to include("M128 24a8") # Phosphor *regular* bell, aliased to #bell
    expect(bell).not_to include("M128 16a16") # not bold

    expect(bundle[%r{<symbol id="gear".*?</symbol>}m]).to include("M128 80a48") # Phosphor gear

    # only the rendered set ships: no raw set ids, no unused weights
    expect(bundle).not_to include("ph-regular-bell")
    expect(bundle).not_to include("ph-bold-bell")
    expect(bundle).not_to include("ph-fill-bell")

    # the genuine remainder (no Phosphor equivalent) falls back to Font Awesome
    expect(bundle).to match(/id="fab-wikipedia-w"/)
  end

  it "aliases the symbol's own id, not a data-*-id attribute" do
    declare_icon_set!(weight: "regular")
    bundle = SvgSprite.bundle(theme.id)

    # the flask fixture symbol is `<symbol data-foo-id="keep-me" id="ph-regular-flask">`
    expect(bundle).to include('data-foo-id="keep-me"') # data-id left intact
    expect(bundle).to match(/\sid="flask"/) # the real id was rewritten to canonical
    expect(bundle).to include("M99FLASK")
  end

  it "follows the weight setting and busts the cache" do
    declare_icon_set!(weight: "regular")
    version = SvgSprite.version(theme.id)

    theme.update_setting(:weight, "bold")

    bell = SvgSprite.bundle(theme.id)[%r{<symbol id="bell".*?</symbol>}m]
    expect(bell).to include("M128 16a16") # now the bold geometry
    expect(SvgSprite.version(theme.id)).not_to eq(version)
  end

  it "busts the cache when a setting override is removed (back to the default)" do
    declare_icon_set!(weight: "regular")
    theme.update_setting(:weight, "bold")
    version = SvgSprite.version(theme.id)

    ThemeSetting.find_by(theme_id: theme.id, name: "weight").destroy!

    bell = SvgSprite.bundle(theme.id)[%r{<symbol id="bell".*?</symbol>}m]
    expect(bell).to include("M128 24a8") # back to the regular geometry
    expect(SvgSprite.version(theme.id)).not_to eq(version)
  end

  it "busts the cache when the settings YAML default changes" do
    declare_icon_set!(weight: "regular")
    version = SvgSprite.version(theme.id)

    theme.set_field(target: :settings, name: :yaml, value: "weight: bold")
    theme.save!

    bell = SvgSprite.bundle(theme.id)[%r{<symbol id="bell".*?</symbol>}m]
    expect(bell).to include("M128 16a16") # the new default's geometry
    expect(SvgSprite.version(theme.id)).not_to eq(version)
  end

  it "keeps client replaceIcon targets resolvable (set-aliased or FA fallback)" do
    declare_icon_set!(weight: "regular")
    bundle = SvgSprite.bundle(theme.id)

    # replaceIcon remaps which #id a render points at; the target just needs to
    # exist in the bundle. Both a set-aliased target and an FA-fallback target
    # are present, so e.g. replaceIcon("x", "gear") or ("x", "circle") resolve.
    expect(bundle).to match(/id="gear"/) # set-aliased target -> Phosphor glyph
    expect(bundle).to match(/id="circle"/) # FA-fallback target (unmapped core icon)
  end

  it "caches a round-trip-safe sentinel for themes with no icon set (no cross-cluster crash)" do
    # build_icon_set returns nil -> theme_icon_set caches {} (a Hash survives
    # serialization across DistributedCache/MessageBus to other app servers; a
    # Symbol arrives as a String and bundle would crash for no-icon-set themes).
    key = "icon_set_#{Theme.transform_ids(theme.id).join(",")}"
    expect(SvgSprite.active_icon_set(theme.id)).to be_nil
    expect(SvgSprite.cache.defer_get_set(key) { :unused }).to eq({})
    expect { SvgSprite.bundle(theme.id) }.not_to raise_error
  end

  it "does not register the declaring sprite's raw glyph ids (no dead icon picker entries)" do
    declare_icon_set!
    icons = SvgSprite.all_icons(theme.id)

    expect(icons).not_to include("ph-regular-bell", "ph-bold-bell", "ph-fill-bell")
    expect(SvgSprite.svgs_for(theme.id)).not_to have_key("ph-regular-bell")
  end

  it "degrades to Font Awesome when the icon set is declared but the sprite is missing" do
    declare_icon_set!(sprite: false)
    bundle = SvgSprite.bundle(theme.id)

    expect(bundle[%r{<symbol id="bell".*?</symbol>}m]).not_to include("M128 24a8") # FA, not Phosphor
  end

  it "is not activated by an unrelated theme field that happens to be named icon-set" do
    theme.set_field(
      target: :extra_scss,
      name: SvgSprite::ICON_SET_FIELD_NAME,
      value: ".a { color: red; }",
    )
    theme.save!

    expect(SvgSprite.theme_declares_icon_set?(theme.id)).to eq(false)
    expect(SvgSprite.active_icon_set(theme.id)).to be_nil
    expect { SvgSprite.bundle(theme.id) }.not_to raise_error
  end

  it "ignores a malformed (non-object) icon-set field without crashing" do
    theme.set_field(
      target: :common,
      name: SvgSprite::ICON_SET_FIELD_NAME,
      type: :json,
      value: "[1, 2]", # valid JSON, but an array, not an object
    )
    theme.save!

    expect(SvgSprite.active_icon_set(theme.id)).to be_nil
    expect { SvgSprite.bundle(theme.id) }.not_to raise_error
  end

  it "skips non-string map values without crashing" do
    declare_icon_set!(map: { "bell" => 5, "gear" => "ph-{weight}-gear" })
    bundle = SvgSprite.bundle(theme.id)

    expect(bundle[%r{<symbol id="bell".*?</symbol>}m]).not_to include("M128 24a8") # FA fallback
    expect(bundle[%r{<symbol id="gear".*?</symbol>}m]).to include("M128 80a48") # still aliased
  end

  it "scopes the icon set to themes that include the declaring theme/component" do
    declare_icon_set!
    other = Fabricate(:theme)

    expect(SvgSprite.bundle(theme.id)[%r{<symbol id="bell".*?</symbol>}m]).to include("M128 24a8")
    expect(SvgSprite.bundle(other.id)[%r{<symbol id="bell".*?</symbol>}m]).not_to include(
      "M128 24a8",
    ) # the other theme keeps Font Awesome
    expect(SvgSprite.path(theme.id)).not_to eq(SvgSprite.path(other.id)) # distinct sprite URLs
  end

  it "aliases admin-added icons (svg_icon_subset) beyond the core default set" do
    # "dice" exists in Font Awesome but isn't served by default; "confetti"
    # doesn't exist in Font Awesome at all. Both become servable when an admin
    # lists them (e.g. for a category icon), and both resolve through the set.
    SiteSetting.svg_icon_subset = "dice|confetti"
    declare_icon_set!(
      map: default_map.merge("dice" => "ph-{weight}-dice", "confetti" => "ph-{weight}-confetti"),
    )

    bundle = SvgSprite.bundle(theme.id)
    expect(bundle[%r{<symbol id="dice".*?</symbol>}m]).to include("M99DICE")
    expect(bundle[%r{<symbol id="confetti".*?</symbol>}m]).to include("M99CONFETTI")
  end

  it "keeps the default glyph for icons listed in the well-known ignored_icons setting" do
    declare_icon_set!
    version = SvgSprite.version(theme.id)

    theme.update_setting(:ignored_icons, "bell")

    bundle = SvgSprite.bundle(theme.id)
    expect(bundle[%r{<symbol id="bell".*?</symbol>}m]).not_to include("M128 24a8") # FA again
    expect(bundle[%r{<symbol id="gear".*?</symbol>}m]).to include("M128 80a48") # still aliased
    expect(SvgSprite.version(theme.id)).not_to eq(version) # setting change busted the cache
  end

  it "warns once per rebuild about mapped icons that resolve to no sprite glyph" do
    declare_icon_set!(map: default_map.merge("comment" => "ph-{weight}-typo-comment"))

    allow(Rails.logger).to receive(:warn)
    SvgSprite.bundle(theme.id)
    expect(Rails.logger).to have_received(:warn).with(
      /1 mapped icons have no matching sprite glyph.*comment/,
    )
  end

  it "warns when multiple themes declare an icon set and uses the first" do
    declare_icon_set!
    component = Fabricate(:theme, component: true)
    component.set_field(
      target: :common,
      name: SvgSprite::ICON_SET_FIELD_NAME,
      type: :json,
      value: { "map" => { "bell" => "other-bell" } }.to_json,
    )
    component.save!
    theme.add_relative_theme!(:child, component)

    allow(Rails.logger).to receive(:warn)
    expect(SvgSprite.bundle(theme.id)[%r{<symbol id="bell".*?</symbol>}m]).to include("M128 24a8")
    expect(Rails.logger).to have_received(:warn).with(/Multiple themes declare an icon set/)
  end

  it "supports multiple variant axes, each resolving from its same-named setting" do
    add_sprite!(theme, "phosphor-multiweight-sprite.svg")
    theme.set_field(target: :settings, name: :yaml, value: "prefix: ph\nweight: regular")
    theme.set_field(
      target: :common,
      name: SvgSprite::ICON_SET_FIELD_NAME,
      type: :json,
      value: { "map" => { "bell" => "{prefix}-{weight}-bell" } }.to_json,
    )
    theme.save!

    expect(SvgSprite.bundle(theme.id)[%r{<symbol id="bell".*?</symbol>}m]).to include("M128 24a8")

    theme.update_setting(:weight, "bold")
    expect(SvgSprite.bundle(theme.id)[%r{<symbol id="bell".*?</symbol>}m]).to include("M128 16a16")
  end

  it "keeps plugin-registered icons when an icon set is active" do
    plugin = '<symbol id="my-plugin-icon" viewBox="0 0 1 1"><path d="MPLUGIN"/></symbol>'
    allow(SvgSprite).to receive(:plugin_svgs_by_plugin).and_return(
      "my-plugin" => {
        "my-plugin-icon" => plugin,
      },
    )
    declare_icon_set!

    bundle = SvgSprite.bundle(theme.id)
    expect(bundle).to include("MPLUGIN") # plugin icon not dropped under the icon set
    expect(bundle[%r{<symbol id="bell".*?</symbol>}m]).to include("M128 24a8") # set still aliased
  end

  it "lets another theme's explicit sprite override win over the set for the same icon" do
    declare_icon_set!
    component = Fabricate(:theme, component: true)
    add_sprite!(component, "override-sprite.svg") # ships its own <symbol id="bell">
    component.save!
    theme.add_relative_theme!(:child, component)

    bell = SvgSprite.bundle(theme.id)[%r{<symbol id="bell".*?</symbol>}m]
    expect(bell).to include("M99OVERRIDE") # the explicit override, not the set glyph
  end

  it "falls back to the next declaring theme when the first declaration is malformed" do
    theme.set_field(
      target: :common,
      name: SvgSprite::ICON_SET_FIELD_NAME,
      type: :json,
      value: "{ not json",
    )
    theme.save!

    component = Fabricate(:theme, component: true)
    add_sprite!(component, "phosphor-multiweight-sprite.svg")
    component.set_field(
      target: :common,
      name: SvgSprite::ICON_SET_FIELD_NAME,
      type: :json,
      value: { "map" => { "bell" => "ph-regular-bell" } }.to_json,
    )
    component.save!
    theme.add_relative_theme!(:child, component)

    bell = SvgSprite.bundle(theme.id)[%r{<symbol id="bell".*?</symbol>}m]
    expect(bell).to include("M128 24a8") # the component's valid set applies
  end

  it "drops map entries with unsafe icon names (no id attribute injection)" do
    declare_icon_set!(map: default_map.merge('bell" onload="x' => "ph-regular-bell"))
    bundle = SvgSprite.bundle(theme.id)

    expect(bundle).not_to include("onload")
    expect(bundle[%r{<symbol id="gear".*?</symbol>}m]).to include("M128 80a48") # rest intact
  end

  it "expires the cache when the settings YAML field is destroyed" do
    declare_icon_set!(weight: "bold")
    version = SvgSprite.version(theme.id)

    ThemeField.find_by(theme_id: theme.id, target_id: Theme.targets[:settings]).destroy!

    bell = SvgSprite.bundle(theme.id)[%r{<symbol id="bell".*?</symbol>}m]
    expect(bell).not_to include("M128 16a16") # no longer the bold default
    expect(SvgSprite.version(theme.id)).not_to eq(version)
  end

  it "keeps other themes' custom sprites; only the declaring sprite is an alias source" do
    declare_icon_set!
    component = Fabricate(:theme, component: true)
    add_sprite!(component, "sibling-sprite.svg")
    component.save!
    theme.add_relative_theme!(:child, component)

    bundle = SvgSprite.bundle(theme.id)
    expect(bundle).to include("M99SIBLING") # sibling component's icon still ships
    expect(bundle[%r{<symbol id="bell".*?</symbol>}m]).to include("M128 24a8") # set still aliased
    expect(bundle).not_to include("ph-bold-bell") # declaring sprite stays alias-source-only
  end

  it "resolves the set glyph for server-rendered lookups (svgs_for / raw_svg / search)" do
    declare_icon_set!
    expect(SvgSprite.svgs_for(theme.id)["bell"]).to include("M128 24a8") # Phosphor, not FA
  end

  it "serves a fixed map value (no {weight}) regardless of the weight (always-filled icons)" do
    declare_icon_set!(weight: "regular", map: { "bell" => "ph-fill-bell" })
    bell = SvgSprite.bundle(theme.id)[%r{<symbol id="bell".*?</symbol>}m]
    expect(bell).to include("M128 8a24") # ph-fill-bell, even though weight=regular
  end

  it "picks the first declaring theme in transform_ids order (deterministic)" do
    other = Fabricate(:theme)
    [theme, other].each do |t|
      t.set_field(
        target: :common,
        name: SvgSprite::ICON_SET_FIELD_NAME,
        type: :json,
        value: { "map" => { "bell" => "#{t.id}-bell" } }.to_json,
      )
      t.save!
    end
    expect(SvgSprite.build_icon_set([theme.id, other.id])["map"]).to eq(
      "bell" => "#{theme.id}-bell",
    )
  end
end
