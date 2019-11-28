# frozen_string_literal: true

require 'rails_helper'

describe SvgSprite do

  before do
    SvgSprite.expire_cache
  end

  it 'can generate a bundle' do
    bundle = SvgSprite.bundle
    expect(bundle).to match(/heart/)
    expect(bundle).to match(/angle-double-down/)
  end

  it 'can generate paths' do
    version = SvgSprite.version # Icons won't change for this test
    expect(SvgSprite.path).to eq("/svg-sprite/#{Discourse.current_hostname}/svg--#{version}.js")
    expect(SvgSprite.path([1, 2])).to eq("/svg-sprite/#{Discourse.current_hostname}/svg-1,2-#{version}.js")

    # Safe mode
    expect(SvgSprite.path([nil])).to eq("/svg-sprite/#{Discourse.current_hostname}/svg--#{version}.js")
  end

  it 'can search for a specific FA icon' do
    expect(SvgSprite.search("fa-heart")).to match(/heart/)
    expect(SvgSprite.search("poo-storm")).to match(/poo-storm/)
    expect(SvgSprite.search("this-is-not-an-icon")).to eq(false)
  end

  it 'can get a raw SVG for an icon' do
    expect(SvgSprite.raw_svg("fa-heart")).to match(/svg.*svg/) # SVG inside SVG
    expect(SvgSprite.raw_svg("this-is-not-an-icon")).to eq("")
  end

  it 'can get a consistent version string' do
    version1 = SvgSprite.version
    version2 = SvgSprite.version

    expect(version1).to eq(version2)
  end

  it 'version string changes' do
    version1 = SvgSprite.version
    Fabricate(:badge, name: 'Custom Icon Badge', icon: 'fa-gamepad')
    version2 = SvgSprite.version

    expect(version1).not_to eq(version2)
  end

  it 'version should be based on bundled output, not requested icons' do
    theme = Fabricate(:theme)
    fname = "custom-theme-icon-sprite.svg"
    upload = UploadCreator.new(file_from_fixtures(fname), fname, for_theme: true).create_for(-1)

    version1 = SvgSprite.version([theme.id])
    bundle1 = SvgSprite.bundle([theme.id])

    SiteSetting.svg_icon_subset = "my-custom-theme-icon"

    version2 = SvgSprite.version([theme.id])
    bundle2 = SvgSprite.bundle([theme.id])

    # The contents of the bundle should not change, because the icon does not actually exist
    expect(bundle1).to eq(bundle2)
    # Therefore the version hash should not change
    expect(version1).to eq(version2)

    # Now add the icon to the theme
    theme.set_field(target: :common, name: SvgSprite.theme_sprite_variable_name, upload_id: upload.id, type: :theme_upload_var)
    theme.save!

    version3 = SvgSprite.version([theme.id])
    bundle3 = SvgSprite.bundle([theme.id])

    # The version/bundle should be updated
    expect(bundle3).not_to match(bundle2)
    expect(version3).not_to match(version2)
    expect(bundle3).to match(/my-custom-theme-icon/)
  end

  it 'strips whitespace when processing icons' do
    Fabricate(:badge, name: 'Custom Icon Badge', icon: '  fab fa-facebook-messenger  ')
    expect(SvgSprite.all_icons).to include("fab-facebook-messenger")
    expect(SvgSprite.all_icons).not_to include("  fab-facebook-messenger  ")
  end

  it 'includes Font Awesome 4.7 icons from badges' do
    Fabricate(:badge, name: 'Custom Icon Badge', icon: 'fa-gamepad')
    expect(SvgSprite.all_icons).to include("gamepad")
  end

  it 'includes Font Awesome 5 icons from badges' do
    Fabricate(:badge, name: 'Custom Icon Badge', icon: 'far fa-building')
    expect(SvgSprite.all_icons).to include("far-building")
  end

  it 'includes icons defined in theme settings' do
    theme = Fabricate(:theme)

    # Works for default settings:
    theme.set_field(target: :settings, name: :yaml, value: "custom_icon: dragon")
    theme.save!
    expect(SvgSprite.all_icons([theme.id])).to include("dragon")

    # Automatically purges cache when default changes:
    theme.set_field(target: :settings, name: :yaml, value: "custom_icon: gamepad")
    theme.save!
    expect(SvgSprite.all_icons([theme.id])).to include("gamepad")

    # Works when applying override
    theme.update_setting(:custom_icon, "gas-pump")
    theme.save!
    expect(SvgSprite.all_icons([theme.id])).to include("gas-pump")

    # Works when changing override
    theme.update_setting(:custom_icon, "gamepad")
    theme.save!
    expect(SvgSprite.all_icons([theme.id])).to include("gamepad")
    expect(SvgSprite.all_icons([theme.id])).not_to include("gas-pump")

    # FA5 syntax
    theme.update_setting(:custom_icon, "fab fa-bandcamp")
    theme.save!
    expect(SvgSprite.all_icons([theme.id])).to include("fab-bandcamp")

    # Internal Discourse syntax + multiple icons
    theme.update_setting(:custom_icon, "fab-android|dragon")
    theme.save!
    expect(SvgSprite.all_icons([theme.id])).to include("fab-android")
    expect(SvgSprite.all_icons([theme.id])).to include("dragon")

    # Check themes don't leak into non-theme sprite sheet
    expect(SvgSprite.all_icons).not_to include("dragon")

    # Check components are included
    theme.update(component: true)
    theme.save!
    parent_theme = Fabricate(:theme)
    parent_theme.add_relative_theme!(:child, theme)
    expect(SvgSprite.all_icons([parent_theme.id])).to include("dragon")
  end

  it 'includes custom icons from a sprite in a theme' do
    theme = Fabricate(:theme)
    fname = "custom-theme-icon-sprite.svg"

    upload = UploadCreator.new(file_from_fixtures(fname), fname, for_theme: true).create_for(-1)

    theme.set_field(target: :common, name: SvgSprite.theme_sprite_variable_name, upload_id: upload.id, type: :theme_upload_var)
    theme.save!

    expect(Upload.where(id: upload.id)).to be_exist
    expect(SvgSprite.bundle([theme.id])).to match(/my-custom-theme-icon/)
  end

  context "s3" do
    let(:upload_s3) { Fabricate(:upload_s3) }

    before do
      SiteSetting.enable_s3_uploads = true
      SiteSetting.s3_upload_bucket = "s3bucket"
      SiteSetting.s3_access_key_id = "s3_access_key_id"
      SiteSetting.s3_secret_access_key = "s3_secret_access_key"

      stub_request(:get, upload_s3.url).to_return(status: 200, body: "Hello world")
    end

    it 'includes svg sprites in themes stored in s3' do
      theme = Fabricate(:theme)
      theme.set_field(target: :common, name: SvgSprite.theme_sprite_variable_name, upload_id: upload_s3.id, type: :theme_upload_var)
      theme.save!

      sprite_files = SvgSprite.custom_svg_sprites([theme.id]).join("|")

      expect(sprite_files).to match(/#{upload_s3.sha1}/)
      expect(sprite_files).not_to match(/amazonaws/)
    end
  end

  it 'includes icons from SiteSettings' do
    SiteSetting.svg_icon_subset = "blender|drafting-compass|fab-bandcamp"

    all_icons = SvgSprite.all_icons
    expect(all_icons).to include("blender")
    expect(all_icons).to include("drafting-compass")
    expect(all_icons).to include("fab-bandcamp")

    SiteSetting.svg_icon_subset = nil
    SvgSprite.expire_cache
    expect(SvgSprite.all_icons).not_to include("drafting-compass")

    # does not fail on non-string setting
    SiteSetting.svg_icon_subset = false
    SvgSprite.expire_cache
    expect(SvgSprite.all_icons).to be_truthy
  end

  it 'includes icons from plugin registry' do
    DiscoursePluginRegistry.register_svg_icon "blender"
    DiscoursePluginRegistry.register_svg_icon "fab fa-bandcamp"

    expect(SvgSprite.all_icons).to include("blender")
    expect(SvgSprite.all_icons).to include("fab-bandcamp")
  end

  it "includes Font Awesome 4.7 icons as group flair" do
    group = Fabricate(:group, flair_url: "fa-air-freshener")
    expect(SvgSprite.bundle).to match(/air-freshener/)
  end

  it "includes Font Awesome 5 icons as group flair" do
    group = Fabricate(:group, flair_url: "far fa-building")
    expect(SvgSprite.bundle).to match(/building/)
  end
end
