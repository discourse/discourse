require 'rails_helper'

describe SvgSprite do
  before { SvgSprite.expire_cache }

  it 'can generate a bundle' do
    bundle = SvgSprite.bundle
    expect(bundle).to match(/heart/)
    expect(bundle).to match(/angle-double-down/)
  end

  it 'can generate paths' do
    version = SvgSprite.version # Icons won't change for this test
    expect(SvgSprite.path).to eq(
          "/svg-sprite/#{Discourse.current_hostname}/svg--#{version}.js"
        )
    expect(SvgSprite.path([1, 2])).to eq(
          "/svg-sprite/#{Discourse.current_hostname}/svg-1,2-#{version}.js"
        )

    # Safe mode
    expect(SvgSprite.path([nil])).to eq(
          "/svg-sprite/#{Discourse.current_hostname}/svg--#{version}.js"
        )
  end

  it 'can search for a specific FA icon' do
    expect(SvgSprite.search('fa-heart')).to match(/heart/)
    expect(SvgSprite.search('poo-storm')).to match(/poo-storm/)
    expect(SvgSprite.search('this-is-not-an-icon')).to eq(false)
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

  it 'strips whitespace when processing icons' do
    Fabricate(
      :badge,
      name: 'Custom Icon Badge', icon: '  fab fa-facebook-messenger  '
    )
    expect(SvgSprite.all_icons).to include('fab-facebook-messenger')
    expect(SvgSprite.all_icons).not_to include('  fab-facebook-messenger  ')
  end

  it 'includes Font Awesome 4.7 icons from badges' do
    Fabricate(:badge, name: 'Custom Icon Badge', icon: 'fa-gamepad')
    expect(SvgSprite.all_icons).to include('gamepad')
  end

  it 'includes Font Awesome 5 icons from badges' do
    Fabricate(:badge, name: 'Custom Icon Badge', icon: 'far fa-building')
    expect(SvgSprite.all_icons).to include('far-building')
  end

  it 'includes icons defined in theme settings' do
    theme = Fabricate(:theme)

    # Works for default settings:
    theme.set_field(
      target: :settings, name: :yaml, value: 'custom_icon: dragon'
    )
    theme.save!
    expect(SvgSprite.all_icons([theme.id])).to include('dragon')

    # Automatically purges cache when default changes:
    theme.set_field(
      target: :settings, name: :yaml, value: 'custom_icon: gamepad'
    )
    theme.save!
    expect(SvgSprite.all_icons([theme.id])).to include('gamepad')

    # Works when applying override
    theme.update_setting(:custom_icon, 'gas-pump')
    expect(SvgSprite.all_icons([theme.id])).to include('gas-pump')

    # Works when changing override
    theme.update_setting(:custom_icon, 'gamepad')
    expect(SvgSprite.all_icons([theme.id])).to include('gamepad')
    expect(SvgSprite.all_icons([theme.id])).not_to include('gas-pump')

    # FA5 syntax
    theme.update_setting(:custom_icon, 'fab fa-bandcamp')
    expect(SvgSprite.all_icons([theme.id])).to include('fab-bandcamp')

    # Internal Discourse syntax + multiple icons
    theme.update_setting(:custom_icon, 'fab-android|dragon')
    expect(SvgSprite.all_icons([theme.id])).to include('fab-android')
    expect(SvgSprite.all_icons([theme.id])).to include('dragon')

    # Check themes don't leak into non-theme sprite sheet
    expect(SvgSprite.all_icons).not_to include('dragon')

    # Check components are included
    theme.update(component: true)
    parent_theme = Fabricate(:theme)
    parent_theme.add_child_theme!(theme)
    expect(SvgSprite.all_icons([parent_theme.id])).to include('dragon')
  end

  it 'includes custom icons from a sprite in a theme' do
    theme = Fabricate(:theme)
    fname = 'custom-theme-icon-sprite.svg'

    upload =
      UploadCreator.new(file_from_fixtures(fname), fname, for_theme: true)
        .create_for(-1)

    theme.set_field(
      target: :common,
      name: SvgSprite.theme_sprite_variable_name,
      upload_id: upload.id,
      type: :theme_upload_var
    )
    theme.save!

    expect(Upload.where(id: upload.id)).to be_exist
    expect(SvgSprite.bundle([theme.id])).to match(/my-custom-theme-icon/)
  end

  it 'includes icons from SiteSettings' do
    SiteSetting.svg_icon_subset = 'blender|drafting-compass|fab-bandcamp'

    all_icons = SvgSprite.all_icons
    expect(all_icons).to include('blender')
    expect(all_icons).to include('drafting-compass')
    expect(all_icons).to include('fab-bandcamp')

    SiteSetting.svg_icon_subset = nil
    SvgSprite.expire_cache
    expect(SvgSprite.all_icons).not_to include('drafting-compass')

    # does not fail on non-string setting
    SiteSetting.svg_icon_subset = false
    SvgSprite.expire_cache
    expect(SvgSprite.all_icons).to be_truthy
  end

  it 'includes icons from plugin registry' do
    DiscoursePluginRegistry.register_svg_icon 'blender'
    DiscoursePluginRegistry.register_svg_icon 'fab fa-bandcamp'

    expect(SvgSprite.all_icons).to include('blender')
    expect(SvgSprite.all_icons).to include('fab-bandcamp')
  end

  it 'includes Font Awesome 4.7 icons as group flair' do
    group = Fabricate(:group, flair_url: 'fa-air-freshener')
    expect(SvgSprite.bundle).to match(/air-freshener/)
  end

  it 'includes Font Awesome 5 icons as group flair' do
    group = Fabricate(:group, flair_url: 'far fa-building')
    expect(SvgSprite.bundle).to match(/building/)
  end
end
