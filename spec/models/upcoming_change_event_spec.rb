# frozen_string_literal: true

RSpec.describe UpcomingChangeEvent do
  describe ".not_backfilled" do
    it "excludes backfilled events" do
      event_without_data =
        described_class.create!(event_type: :added, upcoming_change_name: "event_without_data")
      explicitly_not_backfilled_event =
        described_class.create!(
          event_type: :added,
          event_data: {
            backfilled: false,
          },
          upcoming_change_name: "explicitly_not_backfilled_event",
        )
      described_class.create!(
        event_type: :added,
        event_data: {
          backfilled: true,
        },
        upcoming_change_name: "backfilled_event",
      )

      expect(described_class.not_backfilled).to contain_exactly(
        event_without_data,
        explicitly_not_backfilled_event,
      )
    end
  end
end
