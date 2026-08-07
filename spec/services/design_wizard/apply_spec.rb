# frozen_string_literal: true

RSpec.describe DesignWizard::Apply do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:theme_id) }
    it { is_expected.to validate_inclusion_of(:theme_id).in_array(Theme::CORE_THEMES.values) }
    it do
      is_expected.to validate_inclusion_of(:base_font).in_array(
        BaseFontSetting.values.map { |font| font[:value] },
      ).allow_nil
    end
    it do
      is_expected.to validate_inclusion_of(:heading_font).in_array(
        BaseFontSetting.values.map { |font| font[:value] },
      ).allow_nil
    end
    it do
      is_expected.to validate_inclusion_of(:homepage).in_array(
        %w[latest new hot categories],
      ).allow_nil
    end
    it do
      is_expected.to validate_inclusion_of(:category_page_style).in_array(
        CategoryPageStyle.values.map { |style| style[:value] },
      ).allow_nil
    end

    it "normalizes the base light palette id to nil" do
      contract =
        described_class.new(
          theme_id: Theme::CORE_THEMES["foundation"],
          light_palette_id: DesignWizard::Apply::BASE_LIGHT_PALETTE_ID,
        )

      expect(contract).to be_valid
      expect(contract.light_palette_id).to be_nil
    end

    it "rejects negative palette ids that are not built-in palettes" do
      contract =
        described_class.new(theme_id: Theme::CORE_THEMES["foundation"], light_palette_id: -99)

      expect(contract).to be_invalid
      expect(contract.errors.of_kind?(:light_palette_id, :inclusion)).to eq(true)
    end

    it "accepts negative palette ids matching built-in palettes" do
      contract =
        described_class.new(
          theme_id: Theme::CORE_THEMES["foundation"],
          dark_palette_id: ColorScheme::NAMES_TO_ID_MAP["Dracula"],
        )

      expect(contract).to be_valid
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:foundation_theme) { Theme.foundation_theme }
    fab!(:horizon_theme) { Theme.horizon_theme }

    let(:guardian) { admin.guardian }
    let(:dependencies) { { guardian: } }
    let(:theme_id) { Theme::CORE_THEMES["foundation"] }
    let(:params) { { theme_id: } }

    context "when the contract isn't valid" do
      let(:params) { { theme_id:, base_font: "not_a_font" } }

      it { is_expected.to fail_a_contract }

      it "does not change the design state" do
        expect { result }.not_to change {
          [
            SiteSetting.default_theme_id,
            SiteSetting.base_font,
            ColorScheme.where(via_wizard: true).count,
          ]
        }
      end
    end

    context "when a palette id isn't a valid built-in palette" do
      let(:params) do
        { theme_id:, dark_palette_id: -99, palettes_user_selectable: true, base_font: "arial" }
      end

      it { is_expected.to fail_a_contract }

      it "does not materialize palettes or change the design state" do
        expect { result }.not_to change {
          [
            foundation_theme.reload.dark_color_scheme_id,
            SiteSetting.default_theme_id,
            SiteSetting.base_font,
            ColorScheme.where(via_wizard: true).count,
          ]
        }
      end
    end

    context "when the current user is not an admin" do
      fab!(:moderator)

      let(:guardian) { moderator.guardian }

      it { is_expected.to fail_a_policy(:current_user_is_admin) }
    end

    context "when the core theme row is missing from the database" do
      before { Theme.where(id: theme_id).delete_all }

      it { is_expected.to fail_to_find_a_model(:theme) }
    end

    context "when a provided palette belongs to another theme" do
      fab!(:horizon_palette) { Fabricate(:color_scheme, theme_id: Theme::CORE_THEMES["horizon"]) }

      let(:params) do
        {
          theme_id:,
          light_palette_id: horizon_palette.id,
          palettes_user_selectable: true,
          base_font: "arial",
        }
      end

      it { is_expected.to fail_a_policy(:palettes_available_to_theme) }

      it "does not resolve palettes or change the design state" do
        expect { result }.not_to change {
          [
            foundation_theme.reload.color_scheme_id,
            SiteSetting.default_theme_id,
            SiteSetting.base_font,
            ColorScheme.where(via_wizard: true).count,
          ]
        }
      end
    end

    context "when a provided palette does not exist" do
      let(:params) do
        { theme_id:, dark_palette_id: 999_999, palettes_user_selectable: true, base_font: "arial" }
      end

      it { is_expected.to fail_a_policy(:palettes_available_to_theme) }

      it "does not materialize palettes or change the design state" do
        expect { result }.not_to change {
          [
            foundation_theme.reload.dark_color_scheme_id,
            SiteSetting.default_theme_id,
            SiteSetting.base_font,
            ColorScheme.where(via_wizard: true).count,
          ]
        }
      end
    end

    context "when applying a theme with fonts, homepage and category page style" do
      let(:params) do
        {
          theme_id: Theme::CORE_THEMES["horizon"],
          base_font: "arial",
          heading_font: "oxanium",
          homepage: "categories",
          category_page_style: "categories_boxes",
        }
      end

      it { is_expected.to run_successfully }

      it "sets the default theme" do
        expect { result }.to change { SiteSetting.default_theme_id }.to(horizon_theme.id)
      end

      it "updates the font settings and logs the changes" do
        expect { result }.to change { SiteSetting.base_font }.to("arial").and change {
                SiteSetting.heading_font
              }.to("oxanium").and change {
                      UserHistory.where(
                        action: UserHistory.actions[:change_site_setting],
                        subject: %w[base_font heading_font],
                      ).count
                    }.by(2)
      end

      it "updates the homepage and category page style" do
        expect { result }.to change { SiteSetting.default_homepage }.to("categories").and change {
                SiteSetting.desktop_category_page_style
              }.to("categories_boxes")
      end
    end

    context "when a site setting is shadowed by a global setting" do
      let(:params) { { theme_id: Theme::CORE_THEMES["horizon"], base_font: "arial" } }

      before { SiteSetting.stubs(:shadowed_settings).returns(Set.new(%i[default_theme_id])) }

      it { is_expected.to fail_a_step(:update_site_settings) }

      it "does not change any site setting" do
        expect { result }.not_to change { [SiteSetting.default_theme_id, SiteSetting.base_font] }
      end
    end

    context "when light and dark palettes are provided" do
      fab!(:light_scheme, :color_scheme)
      fab!(:dark_scheme, :color_scheme)

      let(:params) do
        { theme_id:, light_palette_id: light_scheme.id, dark_palette_id: dark_scheme.id }
      end

      it { is_expected.to run_successfully }

      it "assigns the palettes to the theme" do
        result

        expect(foundation_theme.reload).to have_attributes(
          color_scheme_id: light_scheme.id,
          dark_color_scheme_id: dark_scheme.id,
        )
      end
    end

    context "when no palettes are provided" do
      fab!(:existing_scheme, :color_scheme)

      before do
        foundation_theme.update!(
          color_scheme_id: existing_scheme.id,
          dark_color_scheme_id: existing_scheme.id,
        )
      end

      it { is_expected.to run_successfully }

      it "clears the theme palettes" do
        result

        expect(foundation_theme.reload).to have_attributes(
          color_scheme_id: nil,
          dark_color_scheme_id: nil,
        )
      end
    end

    context "when a dark-only built-in palette is selected" do
      let(:params) do
        {
          theme_id:,
          light_palette_id: DesignWizard::Apply::BASE_LIGHT_PALETTE_ID,
          dark_palette_id: ColorScheme::NAMES_TO_ID_MAP["Dracula"],
        }
      end

      before { ColorScheme.where(via_wizard: true).destroy_all }

      it { is_expected.to run_successfully }

      it "materializes a copy of the built-in palette and assigns it as the dark palette" do
        expect { result }.to change { ColorScheme.where(via_wizard: true).count }.by(1)

        materialized =
          ColorScheme.find_by(
            base_scheme_id: ColorScheme::NAMES_TO_ID_MAP["Dracula"],
            via_wizard: true,
          )
        expect(foundation_theme.reload).to have_attributes(
          color_scheme_id: nil,
          dark_color_scheme_id: materialized.id,
        )
      end

      it "reuses the materialized palette on subsequent runs" do
        result

        expect { described_class.call(params:, **dependencies) }.not_to change {
          ColorScheme.where(via_wizard: true).count
        }
      end
    end

    context "when offering the palettes of a theme that ships its own" do
      fab!(:wizard_scheme) { Fabricate(:color_scheme, via_wizard: true, user_selectable: true) }

      let(:theme_id) { Theme::CORE_THEMES["horizon"] }
      let(:params) { { theme_id:, palettes_user_selectable: true } }

      it { is_expected.to run_successfully }

      it "makes the theme palettes user selectable and disables the others" do
        result

        theme_schemes = ColorScheme.where(theme_id: horizon_theme.id)
        expect(theme_schemes).to be_present
        expect(theme_schemes.pluck(:user_selectable)).to all(eq(true))
        expect(wizard_scheme.reload.user_selectable).to eq(false)
      end
    end

    context "when offering built-in palettes on a theme without its own" do
      let(:params) { { theme_id:, palettes_user_selectable: true } }

      before { ColorScheme.where(via_wizard: true).destroy_all }

      it { is_expected.to run_successfully }

      it "materializes all built-in palettes as user selectable" do
        expect { result }.to change { ColorScheme.where(via_wizard: true).count }.by(7)
        expect(ColorScheme.where(via_wizard: true).pluck(:user_selectable)).to all(eq(true))
      end

      it "disables them all when reapplied without user selectable palettes" do
        result
        described_class.call(params: params.merge(palettes_user_selectable: false), **dependencies)

        expect(ColorScheme.where(via_wizard: true).count).to eq(7)
        expect(ColorScheme.where(via_wizard: true).pluck(:user_selectable)).to all(eq(false))
      end
    end
  end
end
