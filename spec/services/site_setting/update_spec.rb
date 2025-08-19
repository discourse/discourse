# frozen_string_literal: true

RSpec.describe SiteSetting::Update do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of :settings }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, options:, **dependencies) }

    fab!(:admin)
    let(:params) { { settings: } }
    let(:settings) { [{ setting_name: setting_name, value: new_value, backfill: backfill }] }
    let(:backfill) { false }
    let(:options) { { allow_changing_hidden: } }
    let(:dependencies) { { guardian: } }
    let(:setting_name) { :title }
    let(:new_value) { "blah whatever" }
    let(:guardian) { admin.guardian }
    let(:allow_changing_hidden) { [] }

    context "when settings is blank" do
      let(:settings) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when a non-admin user tries to change a setting" do
      let(:guardian) { Guardian.new }

      it { is_expected.to fail_a_policy(:current_user_is_admin) }
    end

    context "when trying to change a deprecated setting" do
      let(:hard_deprecated_setting) { ["suggested_topics", "new_suggested_topics", false, "3.3"] }

      let(:soft_deprecated_setting) do
        ["suggested_topics", "suggested_topics_unread_max_days_old", true, "3.3"]
      end

      let(:setting_name) { :suggested_topics }
      let(:new_value) { 3 }

      context "when trying to change a hard deprecated setting" do
        it "does not pass" do
          stub_const(SiteSettings::DeprecatedSettings, "SETTINGS", [hard_deprecated_setting]) do
            is_expected.to fail_a_policy(:settings_are_not_deprecated)
          end
        end
      end

      context "when trying to change a soft deprecated (renamed) setting" do
        it "updates the new setting" do
          stub_const(SiteSettings::DeprecatedSettings, "SETTINGS", [soft_deprecated_setting]) do
            expect { result }.to change { SiteSetting.suggested_topics_unread_max_days_old }.to(3)
          end
        end
      end
    end

    context "when the user changes a hidden setting" do
      let(:setting_name) { :max_category_nesting }
      let(:new_value) { 3 }

      context "when allow_changing_hidden is empty array" do
        it { is_expected.to fail_a_policy(:settings_are_visible) }
      end

      context "when allow_changing_hidden is including setting" do
        let(:allow_changing_hidden) { [:max_category_nesting] }

        it { is_expected.to run_successfully }

        it "updates the specified setting" do
          expect { result }.to change { SiteSetting.max_category_nesting }.to(3)
        end
      end
    end

    context "when a user changes a setting shadowed by a global variable" do
      let(:setting_name) { :max_category_nesting }
      let(:new_value) { 3 }

      before { SiteSetting.stubs(:shadowed_settings).returns(Set.new([:max_category_nesting])) }

      it { is_expected.to fail_a_policy(:settings_are_unshadowed_globally) }
    end

    context "when the user changes a visible setting" do
      let(:new_value) { "hello this is title" }

      it { is_expected.to run_successfully }

      it "updates the specified setting" do
        expect { result }.to change { SiteSetting.title }.to(new_value)
      end

      it "creates an entry in the staff action logs" do
        expect { result }.to change {
          UserHistory.where(
            action: UserHistory.actions[:change_site_setting],
            subject: "title",
          ).count
        }.by(1)
      end

      context "when value needs cleanup" do
        let(:setting_name) { :max_image_size_kb }
        let(:new_value) { "8zf843" }

        it "cleans up the new setting value before using it" do
          expect { result }.to change { SiteSetting.max_image_size_kb }.to(8843)
        end
      end
    end

    context "when one setting is having invalid value" do
      let(:settings) do
        [
          { setting_name: "title", value: "hello this is title" },
          { setting_name: "default_categories_watching", value: "999999" },
        ]
      end

      it { is_expected.to fail_a_policy(:values_are_valid) }

      it "does not update valid setting" do
        expect { result }.not_to change { SiteSetting.title }
      end
    end

    context "when backfill is requested" do
      let(:settings) do
        [
          { setting_name: "default_hide_profile", value: true, backfill: true },
          { setting_name: "default_hide_presence", value: true, backfill: false },
          { setting_name: "title", value: true, backfill: true },
        ]
      end

      it "calls the relevant class for backfill" do
        SiteSettingUpdateExistingUsers.expects(:call).once.with("default_hide_profile", true, false)

        result
      end
    end
  end
end
