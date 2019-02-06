require 'rails_helper'

describe SvgSprite do

  def all_icons(theme_ids = [])
    SvgSprite.all_icons(theme_ids)
  end

  def bundle(theme_ids = [])
    SvgSprite.bundle(theme_ids)
  end

  def path(theme_ids = [])
    SvgSprite.path(theme_ids)
  end

  def version(theme_ids = [])
    SvgSprite.version(theme_ids)
  end

  before do
    SvgSprite.expire_cache
  end

  it 'can generate a bundle' do
    bundle1 = bundle
    expect(bundle1).to match(/heart/)
    expect(bundle1).to match(/angle-double-down/)
  end

  it 'can generate paths' do
    this_version = version # Icons won't change for this test
    expect(path).to eq("/svg-sprite/#{Discourse.current_hostname}/svg--#{this_version}.js")
    expect(path([1, 2])).to eq("/svg-sprite/#{Discourse.current_hostname}/svg-1,2-#{this_version}.js")

    # Safe mode
    expect(path([nil])).to eq("/svg-sprite/#{Discourse.current_hostname}/svg--#{this_version}.js")
  end

  it 'can search for a specific FA icon' do
    expect(SvgSprite.search("fa-heart")).to match(/heart/)
    expect(SvgSprite.search("poo-storm")).to match(/poo-storm/)
    expect(SvgSprite.search("this-is-not-an-icon")).to eq(false)
  end

  it 'can get a consistent version string' do
    version1 = version
    version2 = version

    expect(version1).to eq(version2)
  end

  it 'version string changes' do
    version1 = version
    Fabricate(:badge, name: 'Custom Icon Badge', icon: 'fa-gamepad')
    version2 = version

    expect(version1).not_to eq(version2)
  end

  it 'strips whitespace when processing icons' do
    Fabricate(:badge, name: 'Custom Icon Badge', icon: '  fab fa-facebook-messenger  ')
    expect(all_icons).to include("fab-facebook-messenger")
    expect(all_icons).not_to include("  fab-facebook-messenger  ")
  end

  it 'includes Font Awesome 4.7 icons from badges' do
    Fabricate(:badge, name: 'Custom Icon Badge', icon: 'fa-gamepad')
    expect(all_icons).to include("gamepad")
  end

  it 'includes Font Awesome 5 icons from badges' do
    Fabricate(:badge, name: 'Custom Icon Badge', icon: 'far fa-building')
    expect(all_icons).to include("far-building")
  end

  it 'includes icons defined in theme settings' do
    theme = Fabricate(:theme)

    # Works for default settings:
    theme.set_field(target: :settings, name: :yaml, value: "custom_icon: dragon")
    theme.save!
    expect(all_icons([theme.id])).to include("dragon")

    # Automatically purges cache when default changes:
    theme.set_field(target: :settings, name: :yaml, value: "custom_icon: gamepad")
    theme.save!
    expect(all_icons([theme.id])).to include("gamepad")

    # Works when applying override
    theme.update_setting(:custom_icon, "gas-pump")
    expect(all_icons([theme.id])).to include("gas-pump")

    # Works when changing override
    theme.update_setting(:custom_icon, "gamepad")
    expect(all_icons([theme.id])).to include("gamepad")
    expect(all_icons([theme.id])).not_to include("gas-pump")

    # FA5 syntax
    theme.update_setting(:custom_icon, "fab fa-bandcamp")
    expect(all_icons([theme.id])).to include("fab-bandcamp")

    # Internal Discourse syntax + multiple icons
    theme.update_setting(:custom_icon, "fab-android|dragon")
    expect(all_icons([theme.id])).to include("fab-android")
    expect(all_icons([theme.id])).to include("dragon")

    # Check themes don't leak into non-theme sprite sheet
    expect(all_icons).not_to include("dragon")

    # Check components are included
    theme.update(component: true)
    parent_theme = Fabricate(:theme)
    parent_theme.add_child_theme!(theme)
    expect(all_icons([parent_theme.id])).to include("dragon")
  end

  it 'includes icons from SiteSettings' do
    SiteSetting.svg_icon_subset = "blender|drafting-compass|fab-bandcamp"

    icons = all_icons
    expect(icons).to include("blender")
    expect(icons).to include("drafting-compass")
    expect(icons).to include("fab-bandcamp")

    SiteSetting.svg_icon_subset = nil
    SvgSprite.expire_cache
    expect(all_icons).not_to include("drafting-compass")

    # does not fail on non-string setting
    SiteSetting.svg_icon_subset = false
    SvgSprite.expire_cache
    expect(all_icons).to be_truthy
  end

  it 'includes icons from plugin registry' do
    DiscoursePluginRegistry.register_svg_icon "blender"
    DiscoursePluginRegistry.register_svg_icon "fab fa-bandcamp"

    expect(all_icons).to include("blender")
    expect(all_icons).to include("fab-bandcamp")
  end

  it "includes Font Awesome 4.7 icons as group flair" do
    group = Fabricate(:group, flair_url: "fa-air-freshener")
    expect(bundle).to match(/air-freshener/)
  end

  it "includes Font Awesome 5 icons as group flair" do
    group = Fabricate(:group, flair_url: "far fa-building")
    expect(bundle).to match(/building/)
  end
end
