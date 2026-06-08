# frozen_string_literal: true

RSpec.describe UpcomingChanges::Action::NotificationDataMerger do
  describe ".call" do
    subject(:result) do
      described_class.call(
        existing_notification_data: existing_notification_data,
        new_change_name: new_change_name,
      )
    end

    let(:new_change_name) { :enable_upload_debug_mode }

    context "when there is no existing notification data" do
      let(:existing_notification_data) { nil }

      it "returns the new change name in arrays" do
        expect(result[:upcoming_change_names]).to eq(["enable_upload_debug_mode"])
        expect(result[:upcoming_change_humanized_names]).to eq(["Enable upload debug mode"])
        expect(result[:count]).to eq(1)
      end
    end

    context "when there is existing notification data in the new format" do
      let(:existing_notification_data) do
        {
          upcoming_change_names: ["other_change"],
          upcoming_change_humanized_names: ["Other change"],
          count: 1,
        }.to_json
      end

      it "merges the new change with existing changes" do
        expect(result[:upcoming_change_names]).to contain_exactly(
          "other_change",
          "enable_upload_debug_mode",
        )
        expect(result[:upcoming_change_humanized_names]).to contain_exactly(
          "Other change",
          "Enable upload debug mode",
        )
        expect(result[:count]).to eq(2)
      end
    end

    context "when there is existing notification data in the old format" do
      let(:existing_notification_data) do
        {
          upcoming_change_name: "other_change",
          upcoming_change_humanized_name: "Other change",
        }.to_json
      end

      it "merges old format into the new array format" do
        expect(result[:upcoming_change_names]).to contain_exactly(
          "other_change",
          "enable_upload_debug_mode",
        )
        expect(result[:upcoming_change_humanized_names]).to contain_exactly(
          "Other change",
          "Enable upload debug mode",
        )
        expect(result[:count]).to eq(2)
      end
    end

    context "when the new change already exists in the notification data" do
      let(:existing_notification_data) do
        {
          upcoming_change_names: ["enable_upload_debug_mode"],
          upcoming_change_humanized_names: ["Enable upload debug mode"],
          count: 1,
        }.to_json
      end

      it "deduplicates the change names" do
        expect(result[:upcoming_change_names]).to eq(["enable_upload_debug_mode"])
        expect(result[:upcoming_change_humanized_names]).to eq(["Enable upload debug mode"])
        expect(result[:count]).to eq(1)
      end
    end

    context "when there are more than MAX_STORED_NAMES changes" do
      let(:existing_notification_data) do
        {
          upcoming_change_names: %w[change_1 change_2 change_3 change_4 change_5 change_6],
          upcoming_change_humanized_names: [
            "Change 1",
            "Change 2",
            "Change 3",
            "Change 4",
            "Change 5",
            "Change 6",
          ],
          count: 6,
        }.to_json
      end

      it "truncates the names arrays to MAX_STORED_NAMES" do
        expect(result[:upcoming_change_names].size).to eq(
          UpcomingChanges::Action::NotificationDataMerger::MAX_STORED_NAMES,
        )
        expect(result[:upcoming_change_humanized_names].size).to eq(
          UpcomingChanges::Action::NotificationDataMerger::MAX_STORED_NAMES,
        )
      end

      it "preserves the accurate total count" do
        expect(result[:count]).to eq(7)
      end

      it "keeps the first MAX_STORED_NAMES names in order" do
        expect(result[:upcoming_change_names]).to eq(
          %w[change_1 change_2 change_3 change_4 change_5],
        )
        expect(result[:upcoming_change_humanized_names]).to eq(
          ["Change 1", "Change 2", "Change 3", "Change 4", "Change 5"],
        )
      end
    end

    context "when exactly at MAX_STORED_NAMES" do
      let(:existing_notification_data) do
        {
          upcoming_change_names: %w[change_1 change_2 change_3 change_4],
          upcoming_change_humanized_names: ["Change 1", "Change 2", "Change 3", "Change 4"],
          count: 4,
        }.to_json
      end

      it "does not truncate when adding one more reaches exactly MAX_STORED_NAMES" do
        expect(result[:upcoming_change_names].size).to eq(5)
        expect(result[:count]).to eq(5)
      end
    end
  end
end
