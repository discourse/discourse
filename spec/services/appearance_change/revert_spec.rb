# frozen_string_literal: true

RSpec.describe AppearanceChange::Revert do
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

    before do
      AppearanceChange::Activate.call(
        params: {
          appearance_change_id: appearance_change.id,
        },
        guardian: acting_user.guardian,
      )
    end

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

    context "when the change isn't live" do
      before { theme.update!(color_scheme: light_palette) }

      it { is_expected.to fail_a_policy(:applied) }
    end

    context "when there is nothing to switch back to" do
      before { appearance_change.reload.update!(previous_state: {}) }

      it { is_expected.to fail_to_find_a_model(:previous_state) }
    end

    context "when a palette to switch back to was deleted" do
      before { light_palette.destroy! }

      it { is_expected.to fail_a_policy(:restorable) }
    end

    context "when the fonts can't be changed" do
      before { SiteSetting.stubs(:shadowed_settings).returns(Set[:base_font]) }

      it { is_expected.to fail_a_step(:restore_site_settings) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "gives the theme back its previous palettes" do
        result

        expect(theme.reload).to have_attributes(
          color_scheme_id: light_palette.id,
          dark_color_scheme_id: dark_palette.id,
        )
      end

      it "restores the previous fonts" do
        expect { result }.to change { SiteSetting.base_font }.to(SiteSetting.defaults[:base_font])
      end

      it "keeps the change so it can be made live again" do
        result

        expect(appearance_change.reload).to have_attributes(previous_state: {}, draft?: false)
      end
    end

    context "with a new theme" do
      fab!(:appearance_change, :theme_appearance_change)

      it "makes the previous theme the default again" do
        previous_default_theme_id =
          appearance_change.reload.previous_state.dig("site_settings", "default_theme_id")

        expect { result }.to change { SiteSetting.default_theme_id }.from(
          appearance_change.theme_id,
        ).to(previous_default_theme_id)
      end
    end
  end
end
