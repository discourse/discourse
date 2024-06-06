# frozen_string_literal: true

RSpec.describe(ReorderFlag) do
  subject(:result) do
    described_class.call(flag_id: flag.id, guardian: current_user.guardian, direction: direction)
  end

  let(:flag) { Flag.order(:position).last }
  let(:direction) { "up" }

  context "when user is not allowed to perform the action" do
    fab!(:current_user) { Fabricate(:user) }

    it { is_expected.to fail_a_policy(:invalid_access) }
  end

  context "when direction is invalid" do
    fab!(:current_user) { Fabricate(:admin) }
    let(:direction) { "side" }

    it { is_expected.to fail_a_contract }
  end

  context "when move is invalid" do
    fab!(:current_user) { Fabricate(:admin) }
    let(:direction) { "down" }

    it { is_expected.to fail_a_policy(:invalid_move) }
  end

  context "when user is allowed to perform the action" do
    fab!(:current_user) { Fabricate(:admin) }

    after do
      described_class.call(flag_id: flag.id, guardian: current_user.guardian, direction: "down")
    end

    it "sets the service result as successful" do
      expect(result).to be_a_success
    end

    it "moves the flag" do
      expect(Flag.order(:position).map(&:name)).to eq(
        %w[notify_user off_topic inappropriate spam illegal notify_moderators],
      )
      result
      expect(Flag.order(:position).map(&:name)).to eq(
        %w[notify_user off_topic inappropriate spam notify_moderators illegal],
      )
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
