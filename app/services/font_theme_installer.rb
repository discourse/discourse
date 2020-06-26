# frozen_string_literal: true

class FontThemeInstaller
  def self.install(font_themes)
    font_themes.each do |attrs|
      new(attrs).install
    end
  end

  def initialize(attrs)
    @name = attrs[:name]
    @font_family_name = attrs[:font_family_name]
    @regular_font_filename = attrs[:regular_font]
    @bold_font_filename = attrs[:bold_font]
  end

  DEFAULT_SCSS = <<~SCSS
    @font-face {
      font-family: $family-name;
      src: url($regular-font) format('truetype');
      font-weight: 400;
    }

    @font-face {
      font-family: $family-name;
      src: url($bold-font) format('truetype');
      font-weight: 700;
    }

    html {
      font-family: $family-name, sans-serif;
    }
  SCSS

  def install
    return if Theme.where(name: @name).exists?

    Theme.transaction do
      theme = Theme.create!(
        name: @name,
        user_id: -1,
        component: true,
        enabled: true
      )

      ThemeField.create!(
        theme: theme,
        target_id: Theme.targets[:common],
        name: "scss",
        type_id: ThemeField.types[:scss],
        value: DEFAULT_SCSS.gsub("$family-name", @font_family_name) # not always sans-serif?
      )

      ThemeField.create!(
        theme: theme,
        target_id: Theme.targets[:common],
        name: "regular-font",
        type_id: ThemeField.types[:theme_upload_var],
        upload: upload_font(@regular_font_filename),
        value: ""
      )

      ThemeField.create!(
        theme: theme,
        target_id: Theme.targets[:common],
        name: "bold-font",
        type_id: ThemeField.types[:theme_upload_var],
        upload: upload_font(@bold_font_filename),
        value: ""
      )
    end
  end

  def upload_font(filename)
    path = "#{Rails.root}/app/assets/fonts/#{filename}"
    UploadCreator.new(File.open(path), File.basename(path), for_theme: true).create_for(-1)
  end
end

# To add to all themes:
# Theme.where(component: false).each do |parent_theme|
#   next if ChildTheme.where(parent_theme_id: parent_theme.id, child_theme_id: font_theme.id).exists?
#   parent_theme.add_relative_theme!(:child, font_theme)
# end
