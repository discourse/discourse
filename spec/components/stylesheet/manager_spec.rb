require 'rails_helper'
require 'stylesheet/compiler'

describe Stylesheet::Manager do
  it 'can correctly compile theme css' do
    theme = Theme.new(
      name: 'parent',
      user_id: -1
    )

    theme.set_field(:common, "scss", ".common{.scss{color: red;}}")
    theme.set_field(:desktop, "scss", ".desktop{.scss{color: red;}}")
    theme.set_field(:mobile, "scss", ".mobile{.scss{color: red;}}")
    theme.set_field(:common, "embedded_scss", ".embedded{.scss{color: red;}}")

    theme.save!


    child_theme = Theme.new(
      name: 'parent',
      user_id: -1,
    )

    child_theme.set_field(:common, "scss", ".child_common{.scss{color: red;}}")
    child_theme.set_field(:desktop, "scss", ".child_desktop{.scss{color: red;}}")
    child_theme.set_field(:mobile, "scss", ".child_mobile{.scss{color: red;}}")
    child_theme.set_field(:common, "embedded_scss", ".child_embedded{.scss{color: red;}}")
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


    child_theme.set_field(:desktop, :scss, ".nothing{color: green;}")
    child_theme.save!

    new_link = Stylesheet::Manager.stylesheet_link_tag(:desktop_theme, 'all', theme.key)

    expect(new_link).not_to eq(old_link)

    # our theme better have a name with the theme_id as part of it
    expect(new_link).to include("/stylesheets/desktop_theme_#{theme.id}_")
  end
end

