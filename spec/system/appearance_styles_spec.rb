# frozen_string_literal: true

describe "Appearance change styles" do
  fab!(:admin)

  let(:light_colors) do
    ColorScheme.base_colors.transform_values { AppearanceStyles::PaletteColors.normalize(it) }
  end
  let(:dark_colors) do
    ColorScheme::BUILT_IN_SCHEMES[:Dark].transform_values do
      AppearanceStyles::PaletteColors.normalize(it)
    end
  end
  let(:appearance_change) do
    AppearanceChange::DraftTheme.call(
      params: {
        name: "Acme",
        light_colors:,
        dark_colors:,
        styles: {
          variables: {
            "--d-button-border-radius" => "20px",
          },
          rules: [
            {
              area: "header",
              declarations: {
                "background" =>
                  "linear-gradient(90deg, var(--header_background), color-mix(in srgb, var(--header_background) 40%, var(--tertiary)))",
              },
            },
          ],
        },
      },
      guardian: admin.guardian,
    )[
      :appearance_change
    ]
  end

  before { sign_in(admin) }

  def computed(selector, property)
    page.evaluate_script(
      "getComputedStyle(document.querySelector(#{selector.to_json})).getPropertyValue(#{property.to_json})",
    ).strip
  end

  it "styles the forum in the preview but never the admin area" do
    visit("/latest?preview_theme_id=#{appearance_change.theme_id}")
    expect(page).to have_css(".topic-list, .no-topics-footer, #main-outlet")
    expect(computed(".d-header", "background-image")).to start_with("linear-gradient")
    expect(computed(":root", "--d-button-border-radius")).to eq("20px")

    visit("/admin?preview_theme_id=#{appearance_change.theme_id}")
    expect(page).to have_css("body.admin-interface")
    # the theme's CSS is on the page, but doesn't apply here
    expect(page).to have_css("link[data-theme-id='#{appearance_change.theme_id}']", visible: false)
    expect(computed(".d-header", "background-image")).to eq("none")
    expect(computed(":root", "--d-button-border-radius")).not_to eq("20px")
  end

  it "renders a theme from its database-cached stylesheet when the files are missing" do
    theme = Fabricate.build(:theme)
    # A theme save broadcasts its stylesheet URLs, which would warm the URL cache.
    allow(theme).to receive(:notify_theme_change)
    theme.set_field(
      target: :common,
      name: :scss,
      value: ":root { --d-button-border-radius: 27px; }",
    )
    theme.save!

    manager = Stylesheet::Manager.new(theme_id: theme.id)
    builder = Stylesheet::Manager::Builder.new(target: :common_theme, theme:, manager:)
    css_path = builder.stylesheet_fullpath
    map_path = builder.source_map_fullpath
    builder.compile
    cached = StylesheetCache.find_by!(target: builder.qualified_target, digest: builder.digest)

    # Make the cached bytes distinguishable from a fresh compilation.
    cached.update!(content: "#{cached.content}\n/* cached theme CSS */")
    File.delete(css_path, map_path)

    visit("/latest?preview_theme_id=#{theme.id}")

    expect(computed(":root", "--d-button-border-radius")).to eq("27px")
    expect(File.binread(css_path)).to eq(cached.content.b)
    expect(File.binread(map_path)).to eq(cached.source_map.b)
  ensure
    FileUtils.rm_f([css_path, map_path].compact)
  end
end
