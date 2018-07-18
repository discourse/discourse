require 'rails_helper'
require 'stylesheet/compiler'

describe Stylesheet::Manager do

  it 'does not crash for missing theme' do
    Theme.clear_default!
    link = Stylesheet::Manager.stylesheet_link_tag(:embedded_theme)
    expect(link).to eq("")

    theme = Theme.create(name: "embedded", user_id: -1)
    SiteSetting.default_theme_key = theme.key

    link = Stylesheet::Manager.stylesheet_link_tag(:embedded_theme)
    expect(link).not_to eq("")
  end

  it 'can correctly compile theme css' do
    theme = Theme.new(
      name: 'parent',
      user_id: -1
    )

    theme.set_field(target: :common, name: "scss", value: ".common{.scss{color: red;}}")
    theme.set_field(target: :desktop, name: "scss", value: ".desktop{.scss{color: red;}}")
    theme.set_field(target: :mobile, name: "scss", value: ".mobile{.scss{color: red;}}")
    theme.set_field(target: :common, name: "embedded_scss", value: ".embedded{.scss{color: red;}}")

    theme.save!

    child_theme = Theme.new(
      name: 'parent',
      user_id: -1,
    )

    child_theme.set_field(target: :common, name: "scss", value: ".child_common{.scss{color: red;}}")
    child_theme.set_field(target: :desktop, name: "scss", value: ".child_desktop{.scss{color: red;}}")
    child_theme.set_field(target: :mobile, name: "scss", value: ".child_mobile{.scss{color: red;}}")
    child_theme.set_field(target: :common, name: "embedded_scss", value: ".child_embedded{.scss{color: red;}}")
    child_theme.save!

    theme.add_child_theme!(child_theme)

    old_link = Stylesheet::Manager.stylesheet_link_tag(:desktop_theme, 'all', theme.key)

    manager = Stylesheet::Manager.new(:desktop_theme, theme.key)
    manager.compile(force: true)

    css = File.read(manager.stylesheet_fullpath)
    _source_map = File.read(manager.source_map_fullpath)

    expect(css).to match(/child_common/)
    expect(css).to match(/child_desktop/)
    expect(css).to match(/\.common/)
    expect(css).to match(/\.desktop/)

    child_theme.set_field(target: :desktop, name: :scss, value: ".nothing{color: green;}")
    child_theme.save!

    new_link = Stylesheet::Manager.stylesheet_link_tag(:desktop_theme, 'all', theme.key)

    expect(new_link).not_to eq(old_link)

    # our theme better have a name with the theme_id as part of it
    expect(new_link).to include("/stylesheets/desktop_theme_#{theme.id}_")
  end

  describe 'digest' do
    after do
      DiscoursePluginRegistry.stylesheets.delete "fake_file"
    end

    it 'can correctly account for plugins in digest' do

      theme = Theme.create!(
        name: 'parent',
        user_id: -1
      )

      manager = Stylesheet::Manager.new(:desktop_theme, theme.key)
      digest1 = manager.digest

      DiscoursePluginRegistry.stylesheets.add "fake_file"

      manager = Stylesheet::Manager.new(:desktop_theme, theme.key)
      digest2 = manager.digest

      expect(digest1).not_to eq(digest2)
    end

    let(:image) { file_from_fixtures("logo.png") }
    let(:image2) { file_from_fixtures("logo-dev.png") }

    it 'can correctly account for theme uploads in digest' do
      theme = Theme.create!(
        name: 'parent',
        user_id: -1
      )

      upload = UploadCreator.new(image, "logo.png").create_for(-1)
      field = ThemeField.create!(
        theme_id: theme.id,
        target_id: Theme.targets[:common],
        name: "logo",
        value: "",
        upload_id: upload.id,
        type_id: ThemeField.types[:theme_upload_var]
      )

      manager = Stylesheet::Manager.new(:desktop_theme, theme.key)
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

      manager = Stylesheet::Manager.new(:desktop_theme, theme.key)
      digest2 = manager.digest

      expect(digest1).not_to eq(digest2)
    end
  end

  describe 'color_scheme_digest' do
    it "changes with category background image" do
      theme = Theme.new(
        name: 'parent',
        user_id: -1
      )
      category1 = Fabricate(:category, uploaded_background_id: 123, updated_at: 1.week.ago)
      category2 = Fabricate(:category, uploaded_background_id: 456, updated_at: 2.days.ago)

      manager = Stylesheet::Manager.new(:desktop_theme, theme.key)

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
end
