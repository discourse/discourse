# frozen_string_literal: true

describe "Admin Color Palette Config Area Page", type: :system do
  fab!(:admin)
  fab!(:color_scheme) { Fabricate(:color_scheme, user_selectable: false, name: "A Test Palette") }
  fab!(:color_scheme_2, :color_scheme)

  let(:config_area) { PageObjects::Pages::AdminColorPaletteConfigArea.new }
  let(:toasts) { PageObjects::Components::Toasts.new }
  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:cdp) { PageObjects::CDP.new }

  before { sign_in(admin) }

  it "allows editing the palette name" do
    config_area.visit(color_scheme.id)

    config_area.edit_name_button.click
    config_area.name_field.fill_in("Changed name 2.0")

    expect(config_area).to have_unsaved_changes_indicator

    config_area.form.submit

    expect(toasts).to have_success(I18n.t("js.saved"))
    expect(config_area).to have_no_unsaved_changes_indicator
    expect(color_scheme.reload.name).to eq("Changed name 2.0")
    expect(config_area.name_heading.text).to eq("Changed name 2.0")
  end

  it "allows quick-saving just the name without affecting other changes" do
    config_area.visit(color_scheme.id)

    config_area.edit_name_button.click
    config_area.name_field.fill_in("Quick saved name")
    config_area.color_palette_editor.input_for_color("primary").fill_in(with: "#abcdef")

    expect(config_area).to have_unsaved_changes_indicator

    config_area.name_save_button.click

    expect(toasts).to have_success(I18n.t("js.saved"))
    toasts.close_button.click

    expect(color_scheme.reload.name).to eq("Quick saved name")

    expect(config_area).to have_unsaved_changes_indicator
    expect(color_scheme.colors.find_by(name: "primary")).to eq(nil)

    config_area.form.submit
    expect(toasts).to have_success(I18n.t("js.saved"))
    expect(config_area).to have_no_unsaved_changes_indicator
    expect(color_scheme.colors.reload.find_by(name: "primary").hex).to eq("abcdef")
  end

  it "allows changing the user selectable field" do
    config_area.visit(color_scheme.id)

    config_area.user_selectable_field.toggle

    expect(config_area).to have_unsaved_changes_indicator

    config_area.form.submit

    expect(toasts).to have_success(I18n.t("js.saved"))
    expect(config_area).to have_no_unsaved_changes_indicator
    expect(config_area.user_selectable_field.value).to eq(true)
    expect(color_scheme.reload.user_selectable).to eq(true)
  end

  it "allows changing colors" do
    config_area.visit(color_scheme.id)

    config_area.color_palette_editor.input_for_color("primary").fill_in(with: "#abcdef")

    expect(config_area).to have_unsaved_changes_indicator

    config_area.form.submit

    expect(toasts).to have_success(I18n.t("js.saved"))
    expect(config_area).to have_no_unsaved_changes_indicator

    expect(config_area.color_palette_editor.input_for_color("primary").value).to eq("#abcdef")

    expect(color_scheme.colors.find_by(name: "primary").hex).to eq("abcdef")
  end

  it "supports pasting color codes with and without leading #" do
    config_area.visit(color_scheme.id)

    config_area.color_palette_editor.input_for_hex("primary").click
    cdp.copy_paste("#888888")

    expect(config_area.color_palette_editor.input_for_color("primary").value).to eq("#888888")

    config_area.color_palette_editor.input_for_hex("primary").click
    cdp.copy_paste("#777777")

    expect(config_area.color_palette_editor.input_for_color("primary").value).to eq("#777777")
  end

  it "allows reverting colors to their default values" do
    color_scheme.update!(base_scheme_id: ColorScheme::NAMES_TO_ID_MAP["Dark"])
    color_scheme.colors.create!(name: "primary", hex: "aaaaaa")

    config_area.visit(color_scheme.id)

    expect(config_area.color_palette_editor).to have_revert_button_for_color("primary")

    config_area.color_palette_editor.revert_button_for_color("primary").click

    expect(config_area.color_palette_editor.input_for_color("primary").value.downcase).to eq(
      "#dddddd",
    ) # Dark palette's primary is dddddd
    expect(config_area).to have_unsaved_changes_indicator

    config_area.form.submit

    expect(color_scheme.colors.reload.find_by(name: "primary").hex).to eq("dddddd")
    expect(config_area).to have_no_unsaved_changes_indicator
    expect(config_area.color_palette_editor).to have_no_revert_button_for_color("primary")
  end

  it "allows duplicating the color palette" do
    max_id = ColorScheme.maximum(:id)
    color_scheme.update!(user_selectable: true)

    config_area.visit(color_scheme.id)

    expect(config_area.user_selectable_field.value).to eq(true)

    config_area.duplicate_button.click

    expect(page).to have_current_path("/admin/config/colors/#{max_id + 1}")
    expect(config_area).to have_no_unsaved_changes_indicator
    expect(config_area.name_heading.text).to eq(
      I18n.t("admin_js.admin.config_areas.color_palettes.copy_of", name: color_scheme.name),
    )
    expect(toasts).to have_success(
      I18n.t("admin_js.admin.config_areas.color_palettes.copy_created", name: color_scheme.name),
    )
    expect(config_area.user_selectable_field.value).to eq(false)
  end

  it "allows deleting a color palette" do
    config_area.visit(color_scheme.id)

    config_area.delete_button.click

    dialog.click_danger

    expect(page).to have_current_path("/admin/config/colors")

    expect(ColorScheme.exists?(color_scheme.id)).to eq(false)
  end

  it "applies the changes live when editing the currently active palette" do
    admin.user_option.update!(color_scheme_id: color_scheme.id)
    config_area.visit(color_scheme.id)
    config_area.color_palette_editor.input_for_color("secondary").fill_in(with: "#aa339f")

    expect(config_area).to have_unsaved_changes_indicator
    config_area.form.submit
    expect(toasts).to have_success(I18n.t("js.saved"))
    expect(config_area).to have_no_unsaved_changes_indicator

    href = Stylesheet::Manager.new.color_scheme_stylesheet_link_tag_href(color_scheme.id)

    expect(page).to have_css(
      "link[data-scheme-id=\"#{color_scheme.id}\"][href=\"#{href}\"]",
      visible: false,
    )

    try_until_success(timeout: Capybara.default_max_wait_time * 2) do
      expect(get_rgb_color(find("html"), "backgroundColor")).to eq(
        "rgb(#{"aa".to_i(16)}, #{"33".to_i(16)}, #{"9f".to_i(16)})",
      )
    end
  end

  it "doesn't apply changes when editing a palette that's not currently active" do
    config_area.visit(color_scheme.id)
    config_area.color_palette_editor.input_for_color("secondary").fill_in(with: "#aa339f")

    expect(config_area).to have_unsaved_changes_indicator
    config_area.form.submit
    expect(toasts).to have_success(I18n.t("js.saved"))
    expect(config_area).to have_no_unsaved_changes_indicator

    href = Stylesheet::Manager.new.color_scheme_stylesheet_link_tag_href(color_scheme.id)

    expect(page).to have_no_css("link[href=\"#{href}\"]", visible: false)
  end

  it "can be copied to clipboard" do
    cdp.allow_clipboard

    config_area.visit(color_scheme.id)
    config_area.copy_to_clipboard
    clipboard_content = cdp.read_clipboard
    clipboard_scheme = JSON.parse(clipboard_content)

    expect(clipboard_scheme["name"]).to eq(color_scheme.name)

    color_scheme.colors.each do |color|
      expect(color.hex).to eq(clipboard_scheme["light"][color.name])
    end
  end

  it "can toggle light and dark palette as default on default theme" do
    Theme.find_default.update!(color_scheme: color_scheme)

    config_area.visit(color_scheme.id)
    expect(page).to have_text(
      I18n.t(
        "admin_js.admin.config_areas.color_palettes.color_options.toggle_default_light_on_theme",
        themeName: "Foundation",
      ),
    )
    expect(page).to have_text(
      I18n.t(
        "admin_js.admin.config_areas.color_palettes.color_options.toggle_default_dark_on_theme",
        themeName: "Foundation",
      ),
    )
    config_area.default_light_on_theme_field.have_value?(true)
    config_area.default_dark_on_theme_field.have_value?(false)
    config_area.default_light_on_theme_field.toggle
    config_area.default_dark_on_theme_field.toggle
    config_area.form.submit
    config_area.default_light_on_theme_field.have_value?(false)
    config_area.default_dark_on_theme_field.have_value?(true)

    config_area.visit(color_scheme_2.id)
    config_area.default_light_on_theme_field.have_value?(false)
    config_area.default_dark_on_theme_field.have_value?(false)
  end
end
