# frozen_string_literal: true

RSpec.describe AccessControlList::SearchGrantees do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:limit) }

    it "validates the limit range" do
      expect(described_class.new(limit: 1)).to be_valid
      expect(described_class.new(limit: 0)).not_to be_valid
      expect(
        described_class.new(limit: AccessControlList::SearchGrantees::MAX_RESULTS + 1),
      ).not_to be_valid
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:current_user, :user)

    let(:params) { { term:, limit: } }
    let(:dependencies) { { guardian: } }
    let(:guardian) { current_user.guardian }
    let(:term) { "acl_search" }
    let(:limit) { described_class::MAX_RESULTS }

    context "when the contract is invalid" do
      let(:limit) { 0 }

      it { is_expected.to fail_a_contract }
    end

    context "when the search term is blank" do
      let(:term) { "   " }

      it { is_expected.to run_successfully }

      it "returns empty grantee collections" do
        expect(result.users).to eq([])
        expect(result.groups).to eq([])
      end
    end

    context "when matching grantees exist" do
      fab!(:matching_user) { Fabricate(:user, username: "acl_search_user") }
      fab!(:matching_group) do
        Fabricate(:group, name: "acl_search_group", full_name: "ACL search group")
      end

      it { is_expected.to run_successfully }

      it "returns matching users and groups" do
        expect(result.users.map(&:id)).to contain_exactly(matching_user.id)
        expect(result.groups.map(&:id)).to contain_exactly(matching_group.id)
      end
    end
  end
end
