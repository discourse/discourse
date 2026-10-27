# frozen_string_literal: true

RSpec.describe AppearanceChange::Activate do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:appearance_change_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :admin)
    fab!(:light_palette, :color_scheme)
    fab!(:dark_palette, :color_scheme)
    fab!(:theme) { Fabricate(:theme, color_scheme: light_palette, dark_color_scheme: dark_palette) }
    fab!(:appearance_change) do
      Fabricate(:appearance_change, theme:, site_settings: { "base_font" => "roboto" })
    end

    let(:params) { { appearance_change_id: appearance_change.id } }
    let(:dependencies) { { guardian: acting_user.guardian } }

    context "when data is invalid" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when the change doesn't exist" do
      before { appearance_change.destroy! }

      it { is_expected.to fail_to_find_a_model(:appearance_change) }
    end

    context "when the user can't edit the theme" do
      fab!(:acting_user, :moderator)

      it { is_expected.to fail_a_policy(:can_edit_theme) }
    end

    context "when the change is already live" do
      before do
        theme.update!(
          color_scheme: appearance_change.light_color_scheme,
          dark_color_scheme: appearance_change.dark_color_scheme,
        )
      end

      it { is_expected.to fail_a_policy(:not_applied) }
    end

    context "when one of its palettes was deleted" do
      before { appearance_change.dark_color_scheme.destroy! }

      it { is_expected.to fail_a_policy(:palettes_exist) }
    end

    context "when the fonts can't be changed" do
      before { SiteSetting.stubs(:shadowed_settings).returns(Set[:base_font]) }

      it { is_expected.to fail_a_step(:apply_site_settings) }
    end

    context "when everything's ok" do
      before { freeze_time }

      it { is_expected.to run_successfully }

      it "gives the theme the palettes" do
        result

        expect(theme.reload).to have_attributes(
          color_scheme_id: appearance_change.light_color_scheme_id,
          dark_color_scheme_id: appearance_change.dark_color_scheme_id,
        )
      end

      it "records what it replaces" do
        result

        expect(appearance_change.reload).to have_attributes(
          activated_at: eq_time(Time.zone.now),
          previous_state: {
            "color_scheme_id" => light_palette.id,
            "dark_color_scheme_id" => dark_palette.id,
            "site_settings" => {
              "base_font" => SiteSetting.defaults[:base_font],
            },
          },
        )
      end

      it "applies the fonts" do
        expect { result }.to change { SiteSetting.base_font }.to("roboto")
      end
    end

    context "with palettes the site already had" do
      fab!(:appearance_change) { Fabricate(:appearance_change, kind: :existing_palettes, theme:) }

      it "gives the theme the palettes" do
        result

        expect(theme.reload).to have_attributes(
          color_scheme_id: appearance_change.light_color_scheme_id,
          dark_color_scheme_id: appearance_change.dark_color_scheme_id,
        )
      end
    end

    context "with a new theme" do
      fab!(:appearance_change) do
        Fabricate(:theme_appearance_change, site_settings: { "heading_font" => "roboto" })
      end

      it { is_expected.to run_successfully }

      it "makes the theme the default with its fonts and records what they replace" do
        previous_default_theme_id = SiteSetting.default_theme_id

        expect { result }.to change { SiteSetting.default_theme_id }.to(
          appearance_change.theme_id,
        ).and change { SiteSetting.heading_font }.to("roboto")
        expect(appearance_change.reload.previous_state).to eq(
          "site_settings" => {
            "heading_font" => SiteSetting.defaults[:heading_font],
            "default_theme_id" => previous_default_theme_id,
          },
        )
      end
    end
  end
end
