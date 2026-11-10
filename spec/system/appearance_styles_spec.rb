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
              area: "page",
              declarations: {
                "background-color" => "light-dark(#ffe0f0, #330018)",
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
    expect(computed("body", "background-color")).to eq("rgb(255, 224, 240)")
    expect(computed(":root", "--d-button-border-radius")).to eq("20px")

    visit("/admin?preview_theme_id=#{appearance_change.theme_id}")
    expect(page).to have_css("body.admin-interface")
    # the theme's CSS is on the page, but doesn't apply here
    expect(page).to have_css("link[data-theme-id='#{appearance_change.theme_id}']", visible: false)
    expect(computed("body", "background-color")).not_to eq("rgb(255, 224, 240)")
    expect(computed(":root", "--d-button-border-radius")).not_to eq("20px")
  end
end
