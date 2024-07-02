# frozen_string_literal: true

RSpec.describe(Flags::DestroyFlag) do
  fab!(:flag)

  subject(:result) { described_class.call(id: flag.id, guardian: current_user.guardian) }

  after { flag.destroy }

  context "when user is not allowed to perform the action" do
    fab!(:current_user) { Fabricate(:user) }

    it { is_expected.to fail_a_policy(:invalid_access) }
  end

  context "when user is allowed to perform the action" do
    fab!(:current_user) { Fabricate(:admin) }

    it "sets the service result as successful" do
      expect(result).to be_a_success
    end

    it "destroys the flag" do
      result
      expect { flag.reload }.to raise_error(ActiveRecord::RecordNotFound)
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
