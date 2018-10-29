require 'rails_helper'

describe SvgSprite do
  it 'can generate a bundle' do
    bundle = SvgSprite.bundle
    expect(bundle).to match(/heart/)
    expect(bundle).to match(/angle-double-down/)
  end

  it 'can get a version string' do
    version1 = SvgSprite.version("heart|caret-down")
    version2 = SvgSprite.version("heart|caret-down|caret-up")

    expect(version1).not_to eq(version2)
  end

  it 'includes icons from badges' do
    Fabricate(:badge, name: 'Custom Icon Badge', icon: 'fa-gamepad')
    bundle = SvgSprite.bundle
    expect(bundle).to match(/gamepad/)
  end

  it 'includes icons defined in themes' do
    theme = Fabricate(:theme)
    theme.set_field(target: :settings, name: :yaml, value: "custom_icon: gas-pump")
    theme.save!
    expect(SvgSprite.bundle).to match(/gas-pump/)

    setting = theme.settings.find { |s| s.name == :custom_icon }
    setting.value = 'gamepad'

    expect(SvgSprite.bundle).to match(/gamepad/)
  end

  it 'includes icons from SiteSettings' do
    SiteSetting.svg_icon_subset = 'blender|drafting-compass|'
    bundle = SvgSprite.bundle
    expect(bundle).to match(/blender/)
    expect(bundle).to match(/drafting-compass/)
    expect(bundle).not_to match(/dragon/)
  end

  it 'includes icons from plugins' do
    DiscoursePluginRegistry.register_svg_icon('blender')
    bundle = SvgSprite.bundle
    expect(bundle).to match(/blender/)
  end
end
