# frozen_string_literal: true

require 'rails_helper'

describe SvgSprite do
  fab!(:theme) { Fabricate(:theme) }

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
    expect(SvgSprite.path(1)).to eq("/svg-sprite/#{Discourse.current_hostname}/svg-1-#{version}.js")

    # Safe mode
    expect(SvgSprite.path(nil)).to eq("/svg-sprite/#{Discourse.current_hostname}/svg--#{version}.js")
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
    fname = "custom-theme-icon-sprite.svg"
    upload = UploadCreator.new(file_from_fixtures(fname), fname, for_theme: true).create_for(-1)

    version1 = SvgSprite.version(theme.id)
    bundle1 = SvgSprite.bundle(theme.id)

    SiteSetting.svg_icon_subset = "my-custom-theme-icon"

    version2 = SvgSprite.version(theme.id)
    bundle2 = SvgSprite.bundle(theme.id)

    # The contents of the bundle should not change, because the icon does not actually exist
    expect(bundle1).to eq(bundle2)
    # Therefore the version hash should not change
    expect(version1).to eq(version2)

    # Now add the icon to the theme
    theme.set_field(target: :common, name: SvgSprite.theme_sprite_variable_name, upload_id: upload.id, type: :theme_upload_var)
    theme.save!

    version3 = SvgSprite.version(theme.id)
    bundle3 = SvgSprite.bundle(theme.id)

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

  it 'includes Font Awesome 5 icons from badges' do
    Fabricate(:badge, name: 'Custom Icon Badge', icon: 'far fa-building')
    expect(SvgSprite.all_icons).to include("far-building")
  end

  it 'includes icons defined in theme settings' do
    # Works for default settings:
    theme.set_field(target: :settings, name: :yaml, value: "custom_icon: dragon")
    theme.save!
    expect(SvgSprite.all_icons(theme.id)).to include("dragon")

    # Automatically purges cache when default changes:
    theme.set_field(target: :settings, name: :yaml, value: "custom_icon: gamepad")
    theme.save!
    expect(SvgSprite.all_icons(theme.id)).to include("gamepad")

    # Works when applying override
    theme.update_setting(:custom_icon, "gas-pump")
    theme.save!
    expect(SvgSprite.all_icons(theme.id)).to include("gas-pump")

    # Works when changing override
    theme.update_setting(:custom_icon, "gamepad")
    theme.save!
    expect(SvgSprite.all_icons(theme.id)).to include("gamepad")
    expect(SvgSprite.all_icons(theme.id)).not_to include("gas-pump")

    # FA5 syntax
    theme.update_setting(:custom_icon, "fab fa-bandcamp")
    theme.save!
    expect(SvgSprite.all_icons(theme.id)).to include("fab-bandcamp")

    # Internal Discourse syntax + multiple icons
    theme.update_setting(:custom_icon, "fab-android|dragon")
    theme.save!
    expect(SvgSprite.all_icons(theme.id)).to include("fab-android")
    expect(SvgSprite.all_icons(theme.id)).to include("dragon")

    # Check themes don't leak into non-theme sprite sheet
    expect(SvgSprite.all_icons).not_to include("dragon")

    # Check components are included
    theme.update(component: true)
    theme.save!
    parent_theme = Fabricate(:theme)
    parent_theme.add_relative_theme!(:child, theme)
    expect(SvgSprite.all_icons(parent_theme.id)).to include("dragon")
  end

  it 'includes icons defined in theme modifiers' do
    child_theme = Fabricate(:theme, component: true)
    theme.add_relative_theme!(:child, child_theme)

    expect(SvgSprite.all_icons(theme.id)).not_to include("dragon")

    theme.theme_modifier_set.svg_icons = ["dragon"]
    theme.save!

    child_theme.theme_modifier_set.svg_icons = ["fly"]
    child_theme.save!

    icons = SvgSprite.all_icons(theme.id)

    expect(icons).to include("dragon")
    expect(icons).to include("fly")
  end

  context "s3" do
    let(:upload_s3) { Fabricate(:upload_s3) }

    before do
      setup_s3
      body = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" style="display: none;">
          <symbol id="my-custom-theme-icon" viewBox="0 0 496 512">
            <path d="M248 8C111.03 8 0 119.03 0 256s111.03 248 248 248 248-111.03 248-248S384.97 8 248 8zm0 376c-17.67 0-32-14.33-32-32s14.33-32 32-32 32 14.33 32 32-14.33 32-32 32zm0-128c-53.02 0-96 42.98-96 96s42.98 96 96 96c-106.04 0-192-85.96-192-192S141.96 64 248 64c53.02 0 96 42.98 96 96s-42.98 96-96 96zm0-128c-17.67 0-32 14.33-32 32s14.33 32 32 32 32-14.33 32-32-14.33-32-32-32z"></path>
          </symbol>
        </svg>
      XML
      stub_request(:get, upload_s3.url).to_return(status: 200, body: body)
    end

    it 'includes svg sprites in themes stored in s3' do
      theme.set_field(target: :common, name: SvgSprite.theme_sprite_variable_name, upload_id: upload_s3.id, type: :theme_upload_var)
      theme.save!

      sprite_files = SvgSprite.custom_svg_sprites(theme.id).join("|")
      expect(sprite_files).to match(/my-custom-theme-icon/)

      SvgSprite.bundle(theme.id)
      expect(SvgSprite.cache.hash.keys).to include("custom_svg_sprites_#{theme.id}")

      external_copy = Discourse.store.download(upload_s3)
      File.delete external_copy.try(:path)

      SvgSprite.bundle(theme.id)
      # after a temp file is missing, bundling still works
      expect(SvgSprite.cache.hash.keys).to include("custom_svg_sprites_#{theme.id}")
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

  it "includes Font Awesome icon from groups" do
    group = Fabricate(:group, flair_icon: "far-building")
    expect(SvgSprite.bundle).to match(/far-building/)
  end

  describe "#custom_svg_sprites" do
    it 'is empty by default' do
      expect(SvgSprite.custom_svg_sprites(nil)).to be_empty
      expect(SvgSprite.bundle).not_to be_empty
    end

    context "with a plugin" do
      let :plugin1 do
        plugin1 = Plugin::Instance.new
        plugin1.path = "#{Rails.root}/spec/fixtures/plugins/my_plugin/plugin.rb"
        plugin1
      end

      before do
        Discourse.plugins << plugin1
        plugin1.activate!
      end

      after do
        Discourse.plugins.delete plugin1
        DiscoursePluginRegistry.reset!
      end

      it "includes custom icons from plugins" do
        expect(SvgSprite.custom_svg_sprites(nil).size).to eq(1)
        expect(SvgSprite.bundle).to match(/custom-icon/)
      end
    end

    it 'includes custom icons in a theme' do
      fname = "custom-theme-icon-sprite.svg"

      upload = UploadCreator.new(file_from_fixtures(fname), fname, for_theme: true).create_for(-1)

      theme.set_field(target: :common, name: SvgSprite.theme_sprite_variable_name, upload_id: upload.id, type: :theme_upload_var)
      theme.save!

      expect(Upload.where(id: upload.id)).to be_exist
      expect(SvgSprite.bundle(theme.id)).to match(/my-custom-theme-icon/)
    end

    it 'does not fail on bad XML in custom icon sprite' do
      fname = "bad-xml-icon-sprite.svg"

      upload = UploadCreator.new(file_from_fixtures(fname), fname, for_theme: true).create_for(-1)

      theme.set_field(target: :common, name: SvgSprite.theme_sprite_variable_name, upload_id: upload.id, type: :theme_upload_var)
      theme.save!

      expect(Upload.where(id: upload.id)).to be_exist
      expect(SvgSprite.bundle(theme.id)).to match(/arrow-down/)
    end

    it 'includes custom icons in a child theme' do
      fname = "custom-theme-icon-sprite.svg"
      child_theme = Fabricate(:theme, component: true)
      theme.add_relative_theme!(:child, child_theme)

      upload = UploadCreator.new(file_from_fixtures(fname), fname, for_theme: true).create_for(-1)

      child_theme.set_field(target: :common, name: SvgSprite.theme_sprite_variable_name, upload_id: upload.id, type: :theme_upload_var)
      child_theme.save!

      expect(Upload.where(id: upload.id)).to be_exist
      expect(SvgSprite.bundle(theme.id)).to match(/my-custom-theme-icon/)
    end

  end
end
