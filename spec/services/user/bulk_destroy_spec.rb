# frozen_string_literal: true

RSpec.describe User::BulkDestroy do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_length_of(:user_ids).as_array.is_at_most(100).is_at_least(1) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:users) { Fabricate.times(5, :user) }

    let(:params) { { user_ids:, block_ip_and_email: true } }
    let(:dependencies) { { guardian: } }
    let(:guardian) { admin.guardian }
    let(:user_ids) { users.map(&:id) }

    context "when invalid data is provided" do
      let(:user_ids) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when provided users does not exist" do
      let(:user_ids) { 0 }

      it { is_expected.to fail_to_find_a_model(:users) }
    end

    context "when at least one user cannot be deleted" do
      before { users << Fabricate(:admin) }

      it { is_expected.to fail_a_policy(:can_delete_users) }
    end

    context "when everything's ok" do
      before { allow(MessageBus).to receive(:publish) }

      it "deletes each user" do
        expect { result }.to change { User.where(id: user_ids) }.to be_empty
      end

      it "publishes deletion progress" do
        result
        expect(MessageBus).to have_received(:publish)
          .with("/bulk-user-delete", a_kind_of(Hash), user_ids: [admin.id])
          .exactly(user_ids.size)
          .times
      end
    end
  end
end
