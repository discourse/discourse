# frozen_string_literal: true

RSpec.describe Themes::Create do
  fab!(:user)
  fab!(:admin)
  fab!(:guardian) { admin.guardian }
  fab!(:color_scheme)

  subject(:result) { described_class.call(params:, **dependencies) }

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

  describe "#call" do
    it { is_expected.to be_a_success }

    it "creates a theme with the provided parameters" do
      expect(result).to be_a_success
      expect(result.theme.name).to eq("My Cool Theme")
      expect(result.theme.user_id).to eq(admin.id)
      expect(result.theme.user_selectable).to eq(true)
      expect(result.theme.color_scheme_id).to eq(color_scheme.id)
      expect(result.theme.component).to eq(false)
      expect(result.theme.theme_fields.first.name).to eq("header")
      expect(result.theme.theme_fields.first.value).to eq("header content")
    end

    it "logs the theme change" do
      expect_any_instance_of(StaffActionLogger).to receive(:log_theme_change).with(
        nil,
        an_instance_of(Theme),
      )
      expect(result).to be_a_success
    end

    context "when remote themes are allowlisted" do
      before do
        GlobalSetting.stubs(:allowed_theme_repos).returns(
          "https://github.com/discourse/sample-theme",
        )
      end

      it { is_expected.to fail_a_policy(:ensure_remote_themes_are_not_allowlisted) }
    end

    context "when default param is true" do
      let(:params) { theme_params.merge(default: true) }

      it "sets the theme as default" do
        expect(result).to be_a_success
        expect(result.theme).to be_default
        expect(SiteSetting.default_theme_id).to eq(result.theme.id)
      end

      it "clears the existing default theme" do
        existing_default = Fabricate(:theme)
        existing_default.set_default!
        expect(existing_default.default?).to eq(true)

        expect(result).to be_a_success
        expect(result.theme).to be_default
        expect(existing_default.reload.default?).to eq(false)
        expect(SiteSetting.default_theme_id).to eq(result.theme.id)
      end
    end

    context "with invalid theme field target" do
      let(:params) do
        theme_params.merge(
          theme_fields: [
            { name: "header", target: "invalid_target", value: "header content", type: "html" },
          ],
        )
      end

      it { is_expected.to fail_with_exception(Theme::InvalidFieldTargetError) }
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

      it { is_expected.to fail_with_exception(Theme::InvalidFieldTypeError) }
    end

    context "with empty theme_fields" do
      let(:params) { theme_params.except(:theme_fields) }

      it "creates a theme without fields" do
        expect(result).to be_a_success
        expect(result.theme.theme_fields).to be_empty
      end
    end

    context "with component param" do
      let(:params) do
        theme_params.merge(component: true, user_selectable: false, color_scheme_id: nil)
      end

      it "creates a component" do
        expect(result).to be_a_success
        expect(result.theme).to be_a_component
      end
    end

    context "with invalid model parameters" do
      let(:params) { theme_params.merge(component: true) }

      it "creates a component" do
        expect(result).to fail_with_an_invalid_model(:theme)
        expect(result.theme.errors.full_messages).to eq(
          [
            "Theme components can't have color palettes",
            "Theme components can't be user-selectable",
          ],
        )
      end
    end
  end
end
