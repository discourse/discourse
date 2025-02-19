# frozen_string_literal: true

RSpec.describe(SiteSettingsUpdater) do
  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:current_user) { Fabricate(:admin) }

    let(:params) { { update_hash: { logo: "test", digest_logo: "test" } } }

    context "when the site setting does not exist" do
      let(:params) { { update_hash: { unknown_setting: "test" } } }

      it { is_expected.to fail_a_policy(:not_system) }
    end

    context "when the flag has been used" do
      let!(:post_action) { Fabricate(:post_action, post_action_type_id: flag.id) }

      it { is_expected.to fail_a_policy(:not_used) }
    end

    context "when user is not allowed to perform the action" do
      fab!(:current_user) { Fabricate(:user) }

      it { is_expected.to fail_a_policy(:invalid_access) }
    end

    context "when title is not unique" do
      let!(:flag_2) { Fabricate(:flag, name:) }

      # DO NOT REMOVE: flags have side effects and their state will leak to
      # other examples otherwise.
      after { flag_2.destroy! }

      it { is_expected.to fail_a_policy(:unique_name) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "updates the flag" do
        result
        expect(flag.reload).to have_attributes(
          name: "edited custom flag name",
          description: "edited custom flag description",
          applies_to: ["Topic"],
          require_message: true,
          enabled: false,
          auto_action_type: true,
        )
      end

      it "logs the action" do
        expect { result }.to change { UserHistory.count }.by(1)
        expect(UserHistory.last).to have_attributes(
          custom_type: "update_flag",
          details:
            "name: edited custom flag name\ndescription: edited custom flag description\napplies_to: [\"Topic\"]\nrequire_message: true\nenabled: false",
        )
      end
    end
  end
end
