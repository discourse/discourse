# frozen_string_literal: true

RSpec.describe User::BulkSuspend do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_length_of(:user_ids).as_array.is_at_most(100).is_at_least(1) }
    it { is_expected.to validate_presence_of(:reason) }
    it { is_expected.to validate_length_of(:reason).is_at_most(300) }
    it { is_expected.to validate_presence_of(:suspend_until) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:users) { Fabricate.times(5, :user) }

    let(:params) { { user_ids:, reason: "spam wave", suspend_until: 1.year.from_now } }
    let(:dependencies) { { guardian: } }
    let(:guardian) { admin.guardian }
    let(:user_ids) { users.map(&:id) }

    context "when invalid data is provided" do
      let(:user_ids) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when no reason is provided" do
      let(:params) { { user_ids:, suspend_until: 1.year.from_now } }

      it { is_expected.to fail_a_contract }
    end

    context "when provided users does not exist" do
      let(:user_ids) { 0 }

      it { is_expected.to fail_to_find_a_model(:users) }
    end

    context "when at least one user cannot be suspended" do
      before { users << Fabricate(:admin) }

      it { is_expected.to fail_a_policy(:can_suspend_users) }
    end

    context "when at least one user is already suspended" do
      before { users.first.update!(suspended_till: 1.day.from_now, suspended_at: Time.zone.now) }

      it { is_expected.to fail_a_policy(:can_suspend_users) }
    end

    context "when everything's ok" do
      before { allow(MessageBus).to receive(:publish) }

      it "suspends each user" do
        result
        expect(User.where(id: user_ids).where.not(suspended_till: nil).count).to eq(users.size)
      end

      it "logs the suspension with its reason" do
        result
        histories =
          UserHistory.where(action: UserHistory.actions[:suspend_user], target_user_id: user_ids)
        expect(histories.count).to eq(users.size)
        expect(histories.pluck(:details).uniq).to eq(["spam wave"])
      end

      it "publishes suspension progress" do
        result
        expect(MessageBus).to have_received(:publish)
          .with("/bulk-user-suspend", a_kind_of(Hash), user_ids: [admin.id])
          .exactly(user_ids.size)
          .times
      end
    end
  end
end
