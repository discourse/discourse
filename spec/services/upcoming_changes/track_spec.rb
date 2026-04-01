# frozen_string_literal: true

RSpec.describe UpcomingChanges::Track do
  fab!(:admin_1, :admin)
  fab!(:admin_2, :admin)

  let(:all_admins) { [admin_1, admin_2] }

  describe ".call" do
    subject(:result) { described_class.call(all_admins:) }

    let(:added_changes_result) do
      { added_changes: [:added_change], notified_changes: [:notified_added] }
    end

    let(:removed_changes_result) { [:removed_change] }

    let(:status_changes_result) do
      { status_changes: { status_change: :data }, notified_changes: [:notified_status] }
    end

    before do
      allow(UpcomingChanges::Action::TrackNotifyAddedChanges).to receive(:call).and_return(
        added_changes_result,
      )
      allow(UpcomingChanges::Action::TrackRemovedChanges).to receive(:call).and_return(
        removed_changes_result,
      )
      allow(UpcomingChanges::Action::TrackNotifyStatusChanges).to receive(:call).and_return(
        status_changes_result,
      )
    end

    it "runs successfully" do
      expect(result).to run_successfully
    end

    it "calls TrackNotifyAddedChanges with correct arguments" do
      result
      expect(UpcomingChanges::Action::TrackNotifyAddedChanges).to have_received(:call).with(
        all_admins:,
      )
    end

    it "calls TrackRemovedChanges" do
      result
      expect(UpcomingChanges::Action::TrackRemovedChanges).to have_received(:call)
    end

    it "calls TrackNotifyStatusChanges with correct arguments" do
      result
      expect(UpcomingChanges::Action::TrackNotifyStatusChanges).to have_received(:call).with(
        all_admins:,
        added_changes: [:added_change],
        removed_changes: [:removed_change],
      )
    end

    it "populates the context with results from actions" do
      expect(result).to have_attributes(
        added_changes: [:added_change],
        removed_changes: [:removed_change],
        status_changes: {
          status_change: :data,
        },
        notified_admins_for_added_changes: %i[notified_added notified_status],
      )
    end
  end
end
