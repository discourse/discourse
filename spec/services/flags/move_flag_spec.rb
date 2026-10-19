# frozen_string_literal: true

RSpec.describe Flags::MoveFlag do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:flag_id) }
    it { is_expected.to allow_values(0, 5).for(:position) }
    it { is_expected.not_to allow_values(-1, nil).for(:position) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:current_user, :admin)

    let(:params) { { flag_id:, position: } }
    let(:dependencies) { { guardian: current_user.guardian } }
    let(:flag_id) { flag.id }
    let(:flag) { Flag.find_by(name_key: "notify_moderators") }
    let(:position) { 1 }

    context "when contract is invalid" do
      let(:position) { -1 }

      it { is_expected.to fail_a_contract }
    end

    context "when flag is not found" do
      let(:flag_id) { 0 }

      it { is_expected.to fail_to_find_a_model(:flag) }
    end

    context "when user is not allowed to perform the action" do
      fab!(:current_user, :user)

      it { is_expected.to fail_a_policy(:invalid_access) }
    end

    context "when flag is notify_user" do
      let(:flag) { Flag.find_by(name_key: "notify_user") }

      it { is_expected.to fail_a_policy(:invalid_access) }
    end

    context "when position is out of range" do
      let(:position) { 5 }

      it { is_expected.to fail_a_policy(:invalid_move) }
    end

    context "when everything's ok" do
      let!(:original_positions) { Flag.unscoped.pluck(:id, :position).to_h }

      # A gap in the position values tells reusing them apart from renumbering.
      before { Flag.where(name_key: "notify_moderators").update_all(position: 10) }

      # DO NOT REMOVE: saving a flag reloads the cached flag types after
      # commit, so the moved order will leak to other examples otherwise.
      after do
        original_positions.each { |id, position| Flag.unscoped.where(id:).update_all(position:) }
        Flag.reset_flag_settings!
      end

      it { is_expected.to run_successfully }

      it "moves the flag up to the requested position" do
        expect { result }.to change { Flag.order(:position).map(&:name) }.from(
          %w[notify_user off_topic inappropriate spam illegal notify_moderators],
        ).to(%w[notify_user off_topic notify_moderators inappropriate spam illegal])
      end

      it "reuses the existing position values" do
        expect { result }.not_to change { Flag.order(:position).map(&:position) }.from(
          [1, 2, 3, 4, 5, 10],
        )
      end

      it "logs the action" do
        expect { result }.to change { UserHistory.count }.by(1)
        expect(UserHistory.last).to have_attributes(
          custom_type: "move_flag",
          details: "flag: notify_moderators\nposition: 1",
        )
      end

      context "when moving to the first position" do
        let(:position) { 0 }

        it "places the flag right after notify_user" do
          expect { result }.to change { Flag.order(:position).map(&:name) }.from(
            %w[notify_user off_topic inappropriate spam illegal notify_moderators],
          ).to(%w[notify_user notify_moderators off_topic inappropriate spam illegal])
        end
      end

      context "when moving down to the last position" do
        let(:flag) { Flag.find_by(name_key: "off_topic") }
        let(:position) { 4 }

        it "moves the flag below every other flag" do
          expect { result }.to change { Flag.order(:position).map(&:name) }.from(
            %w[notify_user off_topic inappropriate spam illegal notify_moderators],
          ).to(%w[notify_user inappropriate spam illegal notify_moderators off_topic])
        end
      end
    end
  end
end
