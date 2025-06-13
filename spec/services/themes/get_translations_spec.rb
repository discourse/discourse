# frozen_string_literal: true

RSpec.describe Themes::GetTranslations do
  fab!(:theme)
  fab!(:locale_field_1) do
    ThemeField.create!(
      theme_id: theme.id,
      name: "en",
      type_id: ThemeField.types[:yaml],
      target_id: Theme.targets[:translations],
      value: <<~YAML,
        en:
          theme_metadata:
            description: "Description of my theme"
          skip_to_main_content: "Skip to main contentzz"
          skip_user_nav: "Skip to profile contentzz"
      YAML
    )
  end

  let(:locale) { I18n.available_locales.first.to_s }
  let(:params) { { id: theme.id, locale: locale } }

  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new(params) }

    it { is_expected.to validate_presence_of :id }
    it { is_expected.to validate_presence_of :locale }

    context "when locale is invalid" do
      let(:locale) { "invalid_locale" }

      it "should be invalid" do
        contract.validate
        expect(contract.errors.full_messages).to include(
          I18n.t("errors.messages.invalid_locale", invalid_locale: locale),
        )
      end
    end
  end

  describe "#call" do
    subject(:result) { described_class.call(params:) }

    it { is_expected.to be_a_success }

    it "returns the theme translations" do
      expect(result.translations).to eq(
        [
          {
            key: "skip_to_main_content",
            value: "Skip to main contentzz",
            default: "Skip to main contentzz",
          },
          {
            key: "skip_user_nav",
            value: "Skip to profile contentzz",
            default: "Skip to profile contentzz",
          },
        ],
      )
    end

    context "when theme doesn't exist" do
      before { theme.destroy! }

      it { is_expected.to fail_to_find_a_model(:theme) }
    end
  end
end
