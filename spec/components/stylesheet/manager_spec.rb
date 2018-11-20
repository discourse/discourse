require 'rails_helper'
require 'stylesheet/compiler'

describe Stylesheet::Manager do

  it 'does not crash for missing theme' do
    Theme.clear_default!
    link = Stylesheet::Manager.stylesheet_link_tag(:embedded_theme)
    expect(link).to eq("")

    theme = Fabricate(:theme)
    SiteSetting.default_theme_id = theme.id

    link = Stylesheet::Manager.stylesheet_link_tag(:embedded_theme)
    expect(link).not_to eq("")
  end

  it 'can correctly compile theme css' do
    theme = Fabricate(:theme)

    theme.set_field(target: :common, name: "scss", value: ".common{.scss{color: red;}}")
    theme.set_field(target: :desktop, name: "scss", value: ".desktop{.scss{color: red;}}")
    theme.set_field(target: :mobile, name: "scss", value: ".mobile{.scss{color: red;}}")
    theme.set_field(target: :common, name: "embedded_scss", value: ".embedded{.scss{color: red;}}")

    theme.save!

    child_theme = Fabricate(:theme, component: true)

    child_theme.set_field(target: :common, name: "scss", value: ".child_common{.scss{color: red;}}")
    child_theme.set_field(target: :desktop, name: "scss", value: ".child_desktop{.scss{color: red;}}")
    child_theme.set_field(target: :mobile, name: "scss", value: ".child_mobile{.scss{color: red;}}")
    child_theme.set_field(target: :common, name: "embedded_scss", value: ".child_embedded{.scss{color: red;}}")
    child_theme.save!

    theme.add_child_theme!(child_theme)

    old_link = Stylesheet::Manager.stylesheet_link_tag(:desktop_theme, 'all', theme.id)

    manager = Stylesheet::Manager.new(:desktop_theme, theme.id)
    manager.compile(force: true)

    css = File.read(manager.stylesheet_fullpath)
    _source_map = File.read(manager.source_map_fullpath)

    expect(css).to match(/child_common/)
    expect(css).to match(/child_desktop/)
    expect(css).to match(/\.common/)
    expect(css).to match(/\.desktop/)

    child_theme.set_field(target: :desktop, name: :scss, value: ".nothing{color: green;}")
    child_theme.save!

    new_link = Stylesheet::Manager.stylesheet_link_tag(:desktop_theme, 'all', theme.id)

    expect(new_link).not_to eq(old_link)

    # our theme better have a name with the theme_id as part of it
    expect(new_link).to include("/stylesheets/desktop_theme_#{theme.id}_")
  end

  describe 'digest' do
    after do
      DiscoursePluginRegistry.stylesheets.delete "fake_file"
    end

    it 'can correctly account for plugins in digest' do
      theme = Fabricate(:theme)

      manager = Stylesheet::Manager.new(:desktop_theme, theme.id)
      digest1 = manager.digest

      DiscoursePluginRegistry.stylesheets.add "fake_file"

      manager = Stylesheet::Manager.new(:desktop_theme, theme.id)
      digest2 = manager.digest

      expect(digest1).not_to eq(digest2)
    end

    it "can correctly account for settings in theme's components" do
      theme = Fabricate(:theme)
      child = Fabricate(:theme, component: true)
      theme.add_child_theme!(child)

      child.set_field(target: :settings, name: :yaml, value: "childcolor: red")
      child.set_field(target: :common, name: :scss, value: "body {background-color: $childcolor}")
      child.save!

      manager = Stylesheet::Manager.new(:desktop_theme, theme.id)
      digest1 = manager.digest

      child.update_setting(:childcolor, "green")

      manager = Stylesheet::Manager.new(:desktop_theme, theme.id)
      digest2 = manager.digest

      expect(digest1).not_to eq(digest2)
    end

    let(:image) { file_from_fixtures("logo.png") }
    let(:image2) { file_from_fixtures("logo-dev.png") }

    it 'can correctly account for theme uploads in digest' do
      theme = Fabricate(:theme)

      upload = UploadCreator.new(image, "logo.png").create_for(-1)
      field = ThemeField.create!(
        theme_id: theme.id,
        target_id: Theme.targets[:common],
        name: "logo",
        value: "",
        upload_id: upload.id,
        type_id: ThemeField.types[:theme_upload_var]
      )

      manager = Stylesheet::Manager.new(:desktop_theme, theme.id)
      digest1 = manager.digest
      field.destroy!

      upload = UploadCreator.new(image2, "logo.png").create_for(-1)
      field = ThemeField.create!(
        theme_id: theme.id,
        target_id: Theme.targets[:common],
        name: "logo",
        value: "",
        upload_id: upload.id,
        type_id: ThemeField.types[:theme_upload_var]
      )

      manager = Stylesheet::Manager.new(:desktop_theme, theme.id)
      digest2 = manager.digest

      expect(digest1).not_to eq(digest2)
    end
  end

  describe 'color_scheme_digest' do
    it "changes with category background image" do
      theme = Fabricate(:theme)
      category1 = Fabricate(:category, uploaded_background_id: 123, updated_at: 1.week.ago)
      category2 = Fabricate(:category, uploaded_background_id: 456, updated_at: 2.days.ago)

      manager = Stylesheet::Manager.new(:desktop_theme, theme.id)

      digest1 = manager.color_scheme_digest

      category2.update_attributes(uploaded_background_id: 789, updated_at: 1.day.ago)

      digest2 = manager.color_scheme_digest
      expect(digest2).to_not eq(digest1)

      category1.update_attributes(uploaded_background_id: nil, updated_at: 5.minutes.ago)

      digest3 = manager.color_scheme_digest
      expect(digest3).to_not eq(digest2)
      expect(digest3).to_not eq(digest1)
    end
  end

  # this test takes too long, we don't run it by default
  describe ".precompile_css", if: ENV["RUN_LONG_TESTS"] == "1" do
    before do
      class << STDERR
        alias_method :orig_write, :write
        def write(x)
        end
      end
    end

    after do
      class << STDERR
        def write(x)
          orig_write(x)
        end
      end
      FileUtils.rm_rf("tmp/stylesheet-cache")
    end

    it "correctly generates precompiled CSS" do
      scheme1 = ColorScheme.create!(name: "scheme1")
      scheme2 = ColorScheme.create!(name: "scheme2")
      core_targets = [:desktop, :mobile, :desktop_rtl, :mobile_rtl, :admin]
      theme_targets = [:desktop_theme, :mobile_theme]

      Theme.update_all(user_selectable: false)
      user_theme = Fabricate(:theme, user_selectable: true, color_scheme: scheme1)
      default_theme = Fabricate(:theme, user_selectable: true, color_scheme: scheme2)
      default_theme.set_default!

      StylesheetCache.destroy_all

      Stylesheet::Manager.precompile_css
      results = StylesheetCache.pluck(:target)

      expect(results.size).to eq(14) # 2 themes x 7 targets
      core_targets.each do |tar|
        expect(results.count { |target| target =~ /^#{tar}_(#{scheme1.id}|#{scheme2.id})$/ }).to eq(2)
      end

      theme_targets.each do |tar|
        expect(results.count { |target| target =~ /^#{tar}_(#{user_theme.id}|#{default_theme.id})$/ }).to eq(2)
      end

      Theme.clear_default!
      StylesheetCache.destroy_all

      Stylesheet::Manager.precompile_css
      results = StylesheetCache.pluck(:target)
      expect(results.size).to eq(19) # (2 themes x 7 targets) + (1 no/default/core theme x 5 core targets)

      core_targets.each do |tar|
        expect(results.count { |target| target =~ /^(#{tar}_(#{scheme1.id}|#{scheme2.id})|#{tar})$/ }).to eq(3)
      end

      theme_targets.each do |tar|
        expect(results.count { |target| target =~ /^#{tar}_(#{user_theme.id}|#{default_theme.id})$/ }).to eq(2)
      end
    end
  end
end
