# frozen_string_literal: true

RSpec.describe(Flags::DestroyFlag) do
  subject(:result) { described_class.call(**params, **dependencies) }

  fab!(:flag)
  fab!(:current_user) { Fabricate(:admin) }

  let(:params) { { id: flag_id } }
  let(:dependencies) { { guardian: current_user.guardian } }
  let(:flag_id) { flag.id }

  context "when model is not found" do
    let(:flag_id) { 0 }

    it { is_expected.to fail_to_find_a_model(:flag) }
  end

  context "when the flag is a system one" do
    let(:flag) { Flag.first }

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

  context "when everything's ok" do
    it { is_expected.to run_successfully }

    it "destroys the flag" do
      expect { result }.to change { Flag.where(id: flag).count }.by(-1)
    end

    it "logs the action" do
      expect { result }.to change { UserHistory.count }.by(1)
      expect(UserHistory.last).to have_attributes(
        custom_type: "delete_flag",
        details:
          "name: offtopic\ndescription: \napplies_to: [\"Post\", \"Chat::Message\"]\nenabled: true",
      )
    end
  end
end
