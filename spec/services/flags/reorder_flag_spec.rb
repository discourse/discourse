# frozen_string_literal: true

RSpec.describe(Flags::ReorderFlag) do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:flag_id) }
    it { is_expected.to validate_inclusion_of(:direction).in_array(%w[up down]) }
  end

  describe ".call" do
    subject(:result) { described_class.call(**params, **dependencies) }

    fab!(:current_user) { Fabricate(:admin) }

    let(:params) { { flag_id: flag_id, direction: } }
    let(:dependencies) { { guardian: current_user.guardian } }
    let(:flag_id) { flag.id }
    let(:flag) { Flag.order(:position).last }
    let(:direction) { "up" }

    context "when contract is invalid" do
      let(:direction) { "left" }

      it { is_expected.to fail_a_contract }
    end

    context "when model is not found" do
      let(:flag_id) { 0 }

      it { is_expected.to fail_to_find_a_model(:flag) }
    end

    context "when user is not allowed to perform the action" do
      fab!(:current_user) { Fabricate(:user) }

      it { is_expected.to fail_a_policy(:invalid_access) }
    end

    context "when move is invalid" do
      let(:direction) { "down" }

      it { is_expected.to fail_a_policy(:invalid_move) }
    end

    context "when everything's ok" do
      after do
        described_class.call(flag_id: flag.id, guardian: current_user.guardian, direction: "down")
      end

      it { is_expected.to run_successfully }

      it "moves the flag" do
        expect { result }.to change { Flag.order(:position).map(&:name) }.from(
          %w[notify_user off_topic inappropriate spam illegal notify_moderators],
        ).to(%w[notify_user off_topic inappropriate spam notify_moderators illegal])
      end

      it "logs the action" do
        expect { result }.to change { UserHistory.count }.by(1)
        expect(UserHistory.last).to have_attributes(
          custom_type: "move_flag",
          details: "flag: #{result[:flag].name}\ndirection: up",
        )
      end
    end
  end
end
