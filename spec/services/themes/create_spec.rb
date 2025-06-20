# frozen_string_literal: true

RSpec.describe Themes::Create do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:user_id) }
    it { is_expected.to validate_length_of(:theme_fields).as_array.is_at_least(0).is_at_most(100) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)
    fab!(:admin)
    fab!(:guardian) { admin.guardian }
    fab!(:color_scheme)

    let(:dependencies) { { guardian: } }

    let(:theme_params) do
      {
        name: "My Cool Theme",
        user_id: admin.id,
        user_selectable: true,
        color_scheme_id: color_scheme.id,
        component: false,
        theme_fields: [
          {
            name: "header",
            target: "common",
            value: "header content",
            type_id: ThemeField.types[:html],
          },
        ],
        default: false,
      }
    end

    let(:params) { theme_params }

    context "when remote themes are allowlisted" do
      before do
        GlobalSetting.stubs(:allowed_theme_repos).returns(
          "https://github.com/discourse/sample-theme",
        )
      end

      it { is_expected.to fail_a_policy(:ensure_remote_themes_are_not_allowlisted) }
    end

    context "with invalid theme field target" do
      let(:params) do
        theme_params.merge(
          theme_fields: [
            { name: "header", target: "invalid_target", value: "header content", type: "html" },
          ],
        )
      end

      it { is_expected.to fail_to_find_a_model(:theme) }
    end

    context "with invalid theme field type" do
      let(:params) do
        theme_params.merge(
          theme_fields: [
            {
              name: "header",
              target: "common",
              value: "header content",
              type: "blah", # Invalid type
            },
          ],
        )
      end

      it { is_expected.to fail_to_find_a_model(:theme) }
    end

    context "with invalid component model parameters" do
      let(:params) { theme_params.merge(component: true) }

      it "fails to create a component" do
        expect(result).to fail_with_an_invalid_model(:theme)
        expect(result.theme.errors.full_messages).to eq(
          [
            "Theme components can't have color palettes",
            "Theme components can't be user-selectable",
          ],
        )
      end
    end

    context "when everything is ok" do
      it { is_expected.to run_successfully }

      it "creates a theme with the provided parameters" do
        expect(result.theme).to have_attributes(
          name: "My Cool Theme",
          user_id: admin.id,
          user_selectable: true,
          color_scheme_id: color_scheme.id,
          component: false,
          theme_fields: [have_attributes(name: "header", value: "header content")],
        )
      end

      it "logs the theme change" do
        expect_any_instance_of(StaffActionLogger).to receive(:log_theme_change).with(
          nil,
          an_instance_of(Theme),
        )
        result
      end

      context "with component param" do
        let(:params) do
          theme_params.merge(component: true, user_selectable: false, color_scheme_id: nil)
        end

        it "creates a component" do
          expect(result.theme).to be_a_component
        end
      end

      context "with empty theme_fields" do
        let(:params) { theme_params.except(:theme_fields) }

        it "creates a theme without fields" do
          expect(result.theme.theme_fields).to be_empty
        end
      end

      context "when default param is true" do
        let(:params) { theme_params.merge(default: true) }

        it "sets the theme as default" do
          expect(result.theme).to be_default
          expect(SiteSetting.default_theme_id).to eq(result.theme.id)
        end

        context "when there is an existing default theme" do
          fab!(:existing_default) { Fabricate(:theme) }

          before { existing_default.set_default! }

          it "clears the existing default theme" do
            expect { result }.to change { existing_default.reload.default? }.to(false)
            expect(result.theme).to be_default
            expect(SiteSetting.default_theme_id).to eq(result.theme.id)
          end
        end
      end
    end
  end
end
