# frozen_string_literal: true

RSpec.describe UpcomingChanges::Track do
  fab!(:admin_1, :admin)
  fab!(:admin_2, :admin)

  describe ".call" do
    subject(:result) { described_class.call }

    let(:added_changes_result) { [:added_change] }

    let(:removed_changes_result) { [:removed_change] }

    let(:status_changes_result) { { status_change: :data } }

    before do
      allow(UpcomingChanges::Action::TrackAddedChanges).to receive(:call).and_return(
        added_changes_result,
      )
      allow(UpcomingChanges::Action::TrackRemovedChanges).to receive(:call).and_return(
        removed_changes_result,
      )
      allow(UpcomingChanges::Action::TrackStatusChanges).to receive(:call).and_return(
        status_changes_result,
      )
    end

    it "runs successfully" do
      expect(result).to run_successfully
    end

    it "calls TrackAddedChanges with correct arguments" do
      result
      expect(UpcomingChanges::Action::TrackAddedChanges).to have_received(:call) do |args|
        expect(args[:all_admins]).to contain_exactly(admin_1, admin_2)
      end
    end

    it "calls TrackRemovedChanges" do
      result
      expect(UpcomingChanges::Action::TrackRemovedChanges).to have_received(:call)
    end

    it "calls TrackStatusChanges with correct arguments" do
      result
      expect(UpcomingChanges::Action::TrackStatusChanges).to have_received(:call) do |args|
        expect(args[:all_admins]).to contain_exactly(admin_1, admin_2)
        expect(args[:added_changes]).to eq([:added_change])
        expect(args[:removed_changes]).to eq([:removed_change])
      end
    end

    it "populates the context with results from actions" do
      expect(result).to have_attributes(
        added_changes: [:added_change],
        removed_changes: [:removed_change],
        status_changes: {
          status_change: :data,
        },
      )
    end
  end
end
