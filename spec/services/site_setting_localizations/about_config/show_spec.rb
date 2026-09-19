# frozen_string_literal: true

describe SiteSettingLocalizations::AboutConfig::Show do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:locale) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:user)

    let(:params) { { locale: } }
    let(:dependencies) { { guardian: } }
    let(:guardian) { admin.guardian }
    let(:locale) { "ja" }

    before do
      SiteSetting.content_localization_enabled = true
      SiteSetting.content_localization_supported_locales = "ja|pt_BR"
    end

    context "when locale is blank" do
      let(:locale) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when the user is not an admin" do
      let(:guardian) { user.guardian }

      it { is_expected.to fail_a_policy(:can_localize_site_settings) }
    end

    context "when content localization is disabled" do
      before { SiteSetting.content_localization_enabled = false }

      it { is_expected.to fail_a_policy(:can_localize_site_settings) }
    end

    context "with an unsupported locale" do
      let(:locale) { "de" }

      it { is_expected.to fail_a_policy(:locale_is_supported) }
    end

    context "when everything is ok" do
      before do
        SiteSettingLocalization.create!(setting_name: "title", locale: "ja", value: "日本語タイトル")
        SiteSettingLocalization.create!(
          setting_name: "site_description",
          locale: "pt_BR",
          value: "Descrição",
        )
      end

      it { is_expected.to run_successfully }

      it "returns the localized about settings" do
        expect(result.payload).to eq(
          locale: "ja",
          localizations: {
            "title" => {
              value: "日本語タイトル",
              cooked: nil,
            },
          },
        )
      end
    end
  end
end
