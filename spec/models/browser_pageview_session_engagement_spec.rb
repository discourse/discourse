# frozen_string_literal: true

RSpec.describe BrowserPageviewSessionEngagement do
  describe ".upsert_from_payload" do
    let(:attributes) do
      {
        session_id: "sess-1",
        mouse_move_events: 12,
        click_events: 3,
        key_events: 5,
        scroll_events: 7,
        touch_events: 0,
        back_forward_events: 1,
        engaged_seconds: 4200,
        time_to_first_interaction_ms: 800,
      }
    end

    it "inserts a row with the given metrics" do
      expect { described_class.upsert_from_payload(**attributes) }.to change {
        described_class.count
      }.by(1)

      expect(described_class.find_by(session_id: "sess-1")).to have_attributes(
        mouse_move_events: 12,
        click_events: 3,
        key_events: 5,
        scroll_events: 7,
        touch_events: 0,
        back_forward_events: 1,
        engaged_seconds: 4200,
        time_to_first_interaction_ms: 800,
      )
    end

    it "stores a null time to first interaction when none is reported" do
      described_class.upsert_from_payload(**attributes.merge(time_to_first_interaction_ms: nil))

      expect(described_class.find_by(session_id: "sess-1").time_to_first_interaction_ms).to be_nil
    end

    it "writes nothing when the session id is blank" do
      expect {
        described_class.upsert_from_payload(**attributes.merge(session_id: ""))
        described_class.upsert_from_payload(**attributes.merge(session_id: nil))
      }.not_to change { described_class.count }
    end

    it "updates the existing row for the same session instead of duplicating" do
      described_class.upsert_from_payload(**attributes)

      expect {
        described_class.upsert_from_payload(
          **attributes.merge(mouse_move_events: 40, engaged_seconds: 9000),
        )
      }.not_to change { described_class.count }

      expect(described_class.find_by(session_id: "sess-1")).to have_attributes(
        mouse_move_events: 40,
        engaged_seconds: 9000,
      )
    end
  end
end
