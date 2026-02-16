# frozen_string_literal: true

RSpec.describe SiteSetting::Action::SimpleEmailSubjectToggled do
  describe ".call" do
    subject(:result) { described_class.call(params:) }

    let(:default_email_subject) { SiteSetting.defaults.get(:email_subject) }
    let(:simple_email_subject) { described_class::SIMPLE_EMAIL_SUBJECT }

    context "when enabling" do
      let(:params) { { setting_enabled: true } }

      it { is_expected.to run_successfully }

      it "updates email_subject to the simple format" do
        result
        expect(SiteSetting.email_subject).to eq(simple_email_subject)
      end

      context "when admin has customized email_subject" do
        before { SiteSetting.email_subject = "custom subject" }

        it "does not overwrite the custom email_subject" do
          result
          expect(SiteSetting.email_subject).to eq("custom subject")
        end
      end

      context "when translation overrides exist for keys with _improved variants" do
        let(:translation_key) { "user_notifications.user_posted.subject_template" }
        let(:improved_key) { "#{translation_key}_improved" }
        let(:custom_value) { "custom override" }

        before do
          TranslationOverride.upsert!(SiteSetting.default_locale, translation_key, custom_value)
        end

        it "copies the override to the _improved key" do
          result
          improved_override =
            TranslationOverride.find_by(
              locale: SiteSetting.default_locale,
              translation_key: improved_key,
            )
          expect(improved_override).to be_present
          expect(improved_override.value).to eq(custom_value)
        end
      end

      context "when a translation override key already ends with _improved" do
        let(:original_key) { "user_notifications.user_posted.subject_template" }
        let(:improved_key) { "user_notifications.user_posted.subject_template_improved" }
        let(:original_value) { "original override" }
        let(:improved_value) { "improved override" }

        before do
          TranslationOverride.upsert!(SiteSetting.default_locale, improved_key, improved_value)
        end

        it "does not try to copy the value" do
          result
          improved_override =
            TranslationOverride.find_by(
              locale: SiteSetting.default_locale,
              translation_key: improved_key,
            )
          expect(improved_override).to be_present
          expect(improved_override.value).to eq(improved_value)
        end
      end
    end

    context "when disabling" do
      let(:params) { { setting_enabled: false } }

      before { SiteSetting.email_subject = simple_email_subject }

      it { is_expected.to run_successfully }

      it "resets email_subject to the default" do
        result
        expect(SiteSetting.email_subject).to eq(default_email_subject)
      end

      context "when admin has customized email_subject" do
        before { SiteSetting.email_subject = "custom subject" }

        it "does not overwrite the custom email_subject" do
          result
          expect(SiteSetting.email_subject).to eq("custom subject")
        end
      end

      context "when _improved translation overrides exist" do
        let(:improved_key) { "user_notifications.user_posted.subject_template_improved" }

        before do
          TranslationOverride.upsert!(SiteSetting.default_locale, improved_key, "custom improved")
        end

        it "does not revert the _improved overrides" do
          result
          override =
            TranslationOverride.find_by(
              locale: SiteSetting.default_locale,
              translation_key: improved_key,
            )
          expect(override).to be_present
          expect(override.value).to eq("custom improved")
        end
      end
    end
  end
end
