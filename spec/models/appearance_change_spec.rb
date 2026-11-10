# frozen_string_literal: true

RSpec.describe AppearanceChange do
  def styled_theme_appearance_change
    css = ":root {\n  --d-border-radius: 12px;\n}"
    theme = Fabricate(:theme)
    theme.set_field(target: :common, name: :scss, value: css)
    theme.save!
    Fabricate(
      :theme_appearance_change,
      theme:,
      css:,
      styles: {
        "variables" => {
          "--d-border-radius" => "12px",
        },
      },
    )
  end

  fab!(:theme)

  describe "validations" do
    it "only allows the font site settings" do
      appearance_change =
        Fabricate.build(:appearance_change, site_settings: { "base_font" => "roboto" })
      expect(appearance_change).to be_valid

      appearance_change.site_settings = { "title" => "Something else" }
      expect(appearance_change).not_to be_valid
    end
  end

  describe ".managed_theme_ids" do
    it "lists the themes appearance changes created until files or components are added" do
      palette_only = Fabricate(:theme_appearance_change)
      with_files = Fabricate(:theme_appearance_change)
      with_files.theme.set_field(target: :common, name: :scss, value: "body { color: red; }")
      with_files.theme.save!
      with_component = Fabricate(:theme_appearance_change)
      with_component.theme.add_relative_theme!(:child, Fabricate(:theme, component: true))
      Fabricate(:appearance_change, theme:)

      expect(described_class.managed_theme_ids).to contain_exactly(palette_only.theme_id)
    end

    it "lists themes whose only files are the styles the change wrote" do
      styled = styled_theme_appearance_change
      expect(described_class.managed_theme_ids).to contain_exactly(styled.theme_id)

      styled.theme.set_field(
        target: :common,
        name: :scss,
        value: "#{styled.css}\nbody { color: red; }",
      )
      styled.theme.save!
      expect(described_class.managed_theme_ids).to be_empty
    end
  end

  describe "#applied?" do
    it "is true for a new theme once it is the default" do
      appearance_change = Fabricate(:theme_appearance_change)
      expect(appearance_change.applied?).to eq(false)

      appearance_change.theme.set_default!
      expect(appearance_change.applied?).to eq(true)
    end

    it "is true for palettes once the theme has both of them" do
      appearance_change = Fabricate(:appearance_change, theme:)
      theme.update!(color_scheme: appearance_change.light_color_scheme)
      expect(appearance_change.reload.applied?).to eq(false)

      theme.update!(dark_color_scheme: appearance_change.dark_color_scheme)
      expect(appearance_change.reload.applied?).to eq(true)
    end

    shared_examples "checking the current fonts" do |kind:|
      it "checks both current fonts" do
        appearance_change =
          Fabricate(
            :appearance_change,
            kind:,
            theme:,
            site_settings: {
              "base_font" => "lora",
              "heading_font" => "roboto",
            },
            previous_state: {
              "site_settings" => {
                "base_font" => "inter",
                "heading_font" => "inter",
              },
            },
          )
        theme.update!(
          color_scheme: appearance_change.light_color_scheme,
          dark_color_scheme: appearance_change.dark_color_scheme,
        )
        theme.set_default! if kind == :theme
        SiteSetting.base_font = "lora"
        SiteSetting.heading_font = "roboto"
        expect(appearance_change.reload).to be_applied

        SiteSetting.heading_font = "inter"
        expect(appearance_change).not_to be_applied

        SiteSetting.heading_font = "roboto"
        SiteSetting.base_font = "inter"
        expect(appearance_change).not_to be_applied
      end
    end

    context "with new palettes" do
      include_examples "checking the current fonts", kind: :palettes
    end

    context "with existing palettes" do
      include_examples "checking the current fonts", kind: :existing_palettes
    end

    context "with theme changes" do
      include_examples "checking the current fonts", kind: :theme
    end

    it "is only true for palettes that also set fonts once the change has gone live" do
      appearance_change =
        Fabricate(:appearance_change, theme:, site_settings: { "base_font" => "lora" })
      theme.update!(
        color_scheme: appearance_change.light_color_scheme,
        dark_color_scheme: appearance_change.dark_color_scheme,
      )
      SiteSetting.base_font = "lora"
      expect(appearance_change.reload.applied?).to eq(false)

      appearance_change.update!(previous_state: { "site_settings" => { "base_font" => "inter" } })
      expect(appearance_change.applied?).to eq(true)
    end
  end

  describe "#discard!" do
    it "removes a new theme along with its generated styles" do
      appearance_change = styled_theme_appearance_change

      appearance_change.discard!

      expect(Theme.exists?(appearance_change.theme_id)).to eq(false)
      expect(ThemeField.where(theme_id: appearance_change.theme_id)).to be_empty
    end

    it "removes a new theme along with its palettes" do
      appearance_change = Fabricate(:theme_appearance_change)

      appearance_change.discard!

      expect(described_class.exists?(appearance_change.id)).to eq(false)
      expect(Theme.exists?(appearance_change.theme_id)).to eq(false)
      expect(
        ColorScheme.where(
          id: [appearance_change.light_color_scheme_id, appearance_change.dark_color_scheme_id],
        ),
      ).to be_empty
    end

    it "keeps palettes the site already had" do
      appearance_change = Fabricate(:appearance_change, kind: :existing_palettes)

      appearance_change.discard!

      expect(described_class.exists?(appearance_change.id)).to eq(false)
      expect(
        ColorScheme.where(
          id: [appearance_change.light_color_scheme_id, appearance_change.dark_color_scheme_id],
        ).count,
      ).to eq(2)
    end

    it "keeps a theme members can choose, and the palettes it uses" do
      appearance_change = Fabricate(:theme_appearance_change)
      appearance_change.theme.update!(user_selectable: true)

      appearance_change.discard!

      expect(described_class.exists?(appearance_change.id)).to eq(false)
      expect(Theme.exists?(appearance_change.theme_id)).to eq(true)
      expect(
        ColorScheme.where(
          id: [appearance_change.light_color_scheme_id, appearance_change.dark_color_scheme_id],
        ).count,
      ).to eq(2)
    end

    it "keeps palettes another theme uses" do
      appearance_change = Fabricate(:appearance_change, theme:)
      Fabricate(:theme, color_scheme: appearance_change.light_color_scheme)

      appearance_change.discard!

      expect(ColorScheme.exists?(appearance_change.light_color_scheme_id)).to eq(true)
      expect(ColorScheme.exists?(appearance_change.dark_color_scheme_id)).to eq(false)
    end

    it "keeps palettes another change switches back to" do
      appearance_change = Fabricate(:appearance_change, theme:)
      Fabricate(
        :appearance_change,
        theme:,
        previous_state: {
          "color_scheme_id" => appearance_change.light_color_scheme_id,
          "dark_color_scheme_id" => appearance_change.dark_color_scheme_id,
        },
      )

      appearance_change.discard!

      expect(
        ColorScheme.where(
          id: [appearance_change.light_color_scheme_id, appearance_change.dark_color_scheme_id],
        ).count,
      ).to eq(2)
    end
  end

  # Versions across AppearanceChange::DraftTheme, Activate and Revert.
  describe "#replace_previous_version!" do
    fab!(:admin)

    let(:guardian) { admin.guardian }
    let(:light_colors) do
      ColorScheme.base_colors.transform_values { AppearanceStyles::PaletteColors.normalize(it) }
    end
    let(:dark_colors) do
      ColorScheme::BUILT_IN_SCHEMES[:Dark].transform_values do
        AppearanceStyles::PaletteColors.normalize(it)
      end
    end

    def draft(radius, replaces: nil)
      result =
        AppearanceChange::DraftTheme.call(
          params: {
            name: "Acme",
            light_colors:,
            dark_colors:,
            styles: {
              variables: {
                "--d-border-radius" => radius,
              },
            },
            replaces_theme_id: replaces&.id,
          },
          guardian:,
        )
      expect(result).to be_a_success
      result[:appearance_change]
    end

    def activate(appearance_change)
      result =
        AppearanceChange::Activate.call(
          params: {
            appearance_change_id: appearance_change.id,
          },
          guardian:,
        )
      expect(result).to be_a_success
      appearance_change.reload
    end

    it "keeps a live, a previous and a draft version, and switches back by name" do
      first = activate(draft("8px"))
      expect(first.theme.reload.name).to eq("Acme")

      second = draft("12px", replaces: first.theme)
      expect(second.theme.name).to eq("Acme (draft)")

      activate(second)
      expect(Theme.find_default).to eq(second.theme)
      expect(second.theme.reload.name).to eq("Acme")
      expect(first.theme.reload.name).to eq("Acme (previous)")

      third = activate(draft("16px", replaces: second.theme))
      expect(third.theme.reload.name).to eq("Acme")
      expect(second.theme.reload.name).to eq("Acme (previous)")
      expect(Theme.exists?(first.theme_id)).to eq(false)
      expect(AppearanceChange.exists?(first.id)).to eq(false)
      expect(
        ColorScheme.where(id: [first.light_color_scheme_id, first.dark_color_scheme_id]),
      ).to be_empty

      result = AppearanceChange::Revert.call(params: { appearance_change_id: third.id }, guardian:)
      expect(result).to be_a_success
      expect(Theme.find_default).to eq(second.theme)
      expect(second.theme.reload.name).to eq("Acme")
      expect(third.theme.reload.name).to eq("Acme (draft)")
    end

    it "keeps an old version someone changed or made selectable, as an ordinary theme" do
      first = activate(draft("8px"))
      second = activate(draft("12px", replaces: first.theme))
      first.theme.set_field(target: :common, name: :scss, value: "body { color: red; }")
      first.theme.save!

      activate(draft("16px", replaces: second.theme))

      expect(AppearanceChange.exists?(first.id)).to eq(false)
      expect(first.theme.reload.name).to eq("Acme (previous)")
      expect(first.light_color_scheme.reload).to be_present
    end

    it "only makes new versions of themes nobody has changed or made selectable" do
      first = activate(draft("8px"))

      first.theme.update!(user_selectable: true)
      expect(
        AppearanceChange::DraftTheme.call(
          params: {
            name: "Acme",
            light_colors:,
            dark_colors:,
            replaces_theme_id: first.theme_id,
          },
          guardian:,
        ),
      ).to fail_a_policy(:replaceable_theme)

      first.theme.update!(user_selectable: false)
      first.theme.set_field(target: :common, name: :scss, value: "body { color: red; }")
      first.theme.save!
      expect(
        AppearanceChange::DraftTheme.call(
          params: {
            name: "Acme",
            light_colors:,
            dark_colors:,
            replaces_theme_id: first.theme_id,
          },
          guardian:,
        ),
      ).to fail_a_policy(:replaceable_theme)
    end
  end
end
