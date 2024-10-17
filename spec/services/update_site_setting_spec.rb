# frozen_string_literal: true

RSpec.describe UpdateSiteSetting do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of :setting_name }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, options:, **dependencies) }

    fab!(:admin)
    let(:params) { { setting_name:, new_value: } }
    let(:options) { { allow_changing_hidden: } }
    let(:dependencies) { { guardian: } }
    let(:setting_name) { :title }
    let(:new_value) { "blah whatever" }
    let(:guardian) { admin.guardian }
    let(:allow_changing_hidden) { false }

    context "when setting_name is blank" do
      let(:setting_name) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when a non-admin user tries to change a setting" do
      let(:guardian) { Guardian.new }

      it { is_expected.to fail_a_policy(:current_user_is_admin) }
    end

    context "when the user changes a hidden setting" do
      let(:setting_name) { :max_category_nesting }
      let(:new_value) { 3 }

      context "when allow_changing_hidden is false" do
        it { is_expected.to fail_a_policy(:setting_is_visible) }
      end

      context "when allow_changing_hidden is true" do
        let(:allow_changing_hidden) { true }

        it { is_expected.to run_successfully }

        it "updates the specified setting" do
          expect { result }.to change { SiteSetting.max_category_nesting }.to(3)
        end
      end
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
  end
end
