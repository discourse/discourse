# frozen_string_literal: true

describe SiteSettingLocalizations::AboutConfig::Update do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:locale) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:user)

    let(:params) { { locale:, general_settings: } }
    let(:dependencies) { { guardian: } }
    let(:guardian) { admin.guardian }
    let(:locale) { "ja" }
    let(:general_settings) { { name: "日本語タイトル" } }

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
      let(:general_settings) do
        { name: "日本語タイトル", summary: "日本語の説明", extended_description: "日本語の **詳細** 説明" }
      end

      before do
        SiteSettingLocalization.create!(setting_name: "title", locale: "ja", value: "古いタイトル")
      end

      it { is_expected.to run_successfully }

      it "creates and updates localized about settings" do
        expect { result }.to change {
          SiteSettingLocalization.find_by(setting_name: "title", locale: "ja")&.value
        }.from("古いタイトル").to("日本語タイトル").and change {
                SiteSettingLocalization.exists?(setting_name: "site_description", locale: "ja")
              }.from(false).to(true)

        expect(
          SiteSettingLocalization.find_by(
            setting_name: "extended_site_description",
            locale: "ja",
          ).cooked,
        ).to include("<strong>詳細</strong>")
      end

      it "logs the changed setting names" do
        expect { result }.to change { UserHistory.count }.by(1)

        log_record = UserHistory.where(action: UserHistory.actions[:custom_staff]).last

        aggregate_failures do
          expect(log_record.custom_type).to eq("update_site_setting_localizations")
          expect(log_record.details).to include("locale: ja")
          expect(log_record.details).to include(
            "setting_names: extended_site_description|site_description|title",
          )
        end
      end

      it "returns the updated payload" do
        expect(result.payload[:localizations].dig("title", :value)).to eq("日本語タイトル")
      end
    end

    context "with a blank value" do
      let(:general_settings) { { summary: "" } }

      before do
        SiteSettingLocalization.create!(
          setting_name: "site_description",
          locale: "ja",
          value: "日本語の説明",
        )
      end

      it "removes the localized setting" do
        expect { result }.to change {
          SiteSettingLocalization.exists?(setting_name: "site_description", locale: "ja")
        }.from(true).to(false)
      end
    end

    context "with omitted fields" do
      let(:general_settings) { { name: "日本語タイトル" } }

      before do
        SiteSettingLocalization.create!(
          setting_name: "site_description",
          locale: "ja",
          value: "既存の説明",
        )
      end

      it "does not change existing rows for omitted fields" do
        expect { result }.not_to change {
          SiteSettingLocalization.find_by(setting_name: "site_description", locale: "ja")&.value
        }
      end
    end

    context "with non-general sections" do
      let(:params) do
        {
          locale:,
          general_settings: {
            name: "日本語タイトル",
          },
          contact_information: {
            contact_email: "ignored@example.com",
          },
          your_organization: {
            company_name: "日本語会社",
          },
        }
      end

      it "ignores unsupported about sections" do
        expect { result }.to change {
          SiteSettingLocalization.exists?(setting_name: "title", locale: "ja")
        }.from(false).to(true)

        expect(SiteSettingLocalization.where(locale: "ja").pluck(:setting_name)).to eq(["title"])
      end
    end
  end
end
