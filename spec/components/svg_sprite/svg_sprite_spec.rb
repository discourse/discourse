require 'rails_helper'

describe SvgSprite do
  it 'can generate a bundle' do
    bundle = SvgSprite.bundle
    expect(bundle).to match(/heart/)
    expect(bundle).to match(/angle-double-down/)
  end

  it 'can get a consistent version string' do
    version1 = SvgSprite.version
    version2 = SvgSprite.version

    expect(version1).to eq(version2)
  end

  it 'includes  Font Awesome 4.7 icons from badges' do
    Fabricate(:badge, name: 'Custom Icon Badge', icon: 'fa-gamepad')
    expect(SvgSprite.bundle).to match(/gamepad/)
  end

  it 'includes  Font Awesome 5 icons from badges' do
    Fabricate(:badge, name: 'Custom Icon Badge', icon: 'far fa-building')
    expect(SvgSprite.bundle).to match(/building/)
  end

  it 'includes icons defined in themes' do
    theme = Fabricate(:theme)
    theme.set_field(target: :settings, name: :yaml, value: "custom_icon: gas-pump")
    theme.save!
    expect(SvgSprite.bundle).to match(/gas-pump/)

    setting = theme.settings.find { |s| s.name == :custom_icon }
    setting.value = 'gamepad'
    expect(SvgSprite.bundle).to match(/gamepad/)

    setting = theme.settings.find { |s| s.name == :custom_icon }
    setting.value = 'fab fa-bandcamp'
    expect(SvgSprite.bundle).to match(/fab-bandcamp/)

  end

  it 'includes icons from SiteSettings' do
    SiteSetting.svg_icon_subset = 'blender|drafting-compass|fab-bandcamp'
    bundle = SvgSprite.bundle
    expect(bundle).to match(/blender/)
    expect(bundle).to match(/drafting-compass/)
    expect(bundle).to match(/fab-bandcamp/)
    expect(bundle).not_to match(/dragon/)
  end

  it 'includes icons from plugins' do
    DiscoursePluginRegistry.register_svg_icon('blender')
    DiscoursePluginRegistry.register_svg_icon('fab fa-bandcamp')
    bundle = SvgSprite.bundle
    expect(bundle).to match(/blender/)
    expect(bundle).to match(/fab-bandcamp/)
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
