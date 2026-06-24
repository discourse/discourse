# frozen_string_literal: true

RSpec.describe SiteSetting::Action::RemoveAndReplaceUncategorizedToggled do
  fab!(:uncategorized) { Fabricate(:category, name: "Special category") }

  before do
    SiteSetting.uncategorized_category_id = uncategorized.id
    SiteSetting.allow_uncategorized_topics = true
  end

  describe "enabling" do
    it "demotes the special category in place and disallows uncategorized topics" do
      described_class.call(enabled: true)

      expect(SiteSetting.uncategorized_category_id).to eq(-1)
      expect(SiteSetting.allow_uncategorized_topics).to eq(false)
      expect(uncategorized.reload.uncategorized?).to eq(false)
    end

    it "leaves default_composer_category pointing at the now-normal category" do
      SiteSetting.default_composer_category = uncategorized.id.to_s

      described_class.call(enabled: true)

      expect(SiteSetting.default_composer_category).to eq(uncategorized.id.to_s)
    end

    it "snapshots the prior state onto the existing manual_opt_in event" do
      SiteSetting.default_composer_category = uncategorized.id.to_s
      event =
        UpcomingChangeEvent.create!(
          event_type: :manual_opt_in,
          upcoming_change_name: "remove_and_replace_uncategorized",
        )

      described_class.call(enabled: true)

      expect(event.reload.event_data).to eq(
        "allow_uncategorized_topics" => true,
        "default_composer_category" => uncategorized.id.to_s,
        "uncategorized_category_id" => uncategorized.id,
      )
    end

    it "creates an automatically_promoted event with the snapshot when there is no opt-in event" do
      described_class.call(enabled: true)

      event =
        UpcomingChangeEvent.find_by(
          event_type: :automatically_promoted,
          upcoming_change_name: "remove_and_replace_uncategorized",
        )
      expect(event.event_data["uncategorized_category_id"]).to eq(uncategorized.id)
      expect(event.event_data["allow_uncategorized_topics"]).to eq(true)
    end

    it "captures the snapshot even when an unrelated event already carries event_data" do
      # The framework records a `status_changed` event whose event_data holds the
      # status transition. The snapshot lookup must ignore it, not treat it as an
      # existing snapshot.
      UpcomingChangeEvent.create!(
        event_type: :status_changed,
        upcoming_change_name: "remove_and_replace_uncategorized",
        event_data: {
          previous_value: nil,
          new_value: "experimental",
        },
      )
      opt_in =
        UpcomingChangeEvent.create!(
          event_type: :manual_opt_in,
          upcoming_change_name: "remove_and_replace_uncategorized",
        )

      described_class.call(enabled: true)

      expect(opt_in.reload.event_data).to include("uncategorized_category_id" => uncategorized.id)
    end

    it "is idempotent and does not re-snapshot when already migrated" do
      described_class.call(enabled: true)
      original_event_count = UpcomingChangeEvent.count

      # Simulate drift that should be ignored because the change is already applied.
      SiteSetting.uncategorized_category_id = -1
      described_class.call(enabled: true)

      expect(UpcomingChangeEvent.count).to eq(original_event_count)
    end
  end

  describe "disabling" do
    it "restores the special category and the prior settings from the snapshot" do
      SiteSetting.default_composer_category = uncategorized.id.to_s
      UpcomingChangeEvent.create!(
        event_type: :automatically_promoted,
        upcoming_change_name: "remove_and_replace_uncategorized",
        event_data: {
          allow_uncategorized_topics: true,
          default_composer_category: uncategorized.id.to_s,
          uncategorized_category_id: uncategorized.id,
        },
      )
      # Site is currently in the "enabled" state.
      SiteSetting.uncategorized_category_id = -1
      SiteSetting.allow_uncategorized_topics = false
      SiteSetting.default_composer_category = ""

      described_class.call(enabled: false)

      expect(SiteSetting.uncategorized_category_id).to eq(uncategorized.id)
      expect(SiteSetting.allow_uncategorized_topics).to eq(true)
      expect(SiteSetting.default_composer_category).to eq(uncategorized.id.to_s)
      expect(uncategorized.reload.uncategorized?).to eq(true)
    end

    it "does nothing when the site was not using uncategorized topics at opt-in" do
      UpcomingChangeEvent.create!(
        event_type: :automatically_promoted,
        upcoming_change_name: "remove_and_replace_uncategorized",
        event_data: {
          allow_uncategorized_topics: false,
          default_composer_category: "",
          uncategorized_category_id: uncategorized.id,
        },
      )
      SiteSetting.uncategorized_category_id = -1
      SiteSetting.allow_uncategorized_topics = false

      described_class.call(enabled: false)

      expect(SiteSetting.uncategorized_category_id).to eq(-1)
      expect(SiteSetting.allow_uncategorized_topics).to eq(false)
    end

    it "does nothing when there is no snapshot" do
      SiteSetting.uncategorized_category_id = -1
      SiteSetting.allow_uncategorized_topics = false

      described_class.call(enabled: false)

      expect(SiteSetting.uncategorized_category_id).to eq(-1)
      expect(SiteSetting.allow_uncategorized_topics).to eq(false)
    end
  end

  describe ".should_display_upcoming_change?" do
    it "is displayed while the site allows uncategorized topics" do
      SiteSetting.allow_uncategorized_topics = true
      expect(described_class.should_display_upcoming_change?).to eq(true)
    end

    it "is hidden once uncategorized topics are disallowed and the change is off" do
      SiteSetting.allow_uncategorized_topics = false
      expect(described_class.should_display_upcoming_change?).to eq(false)
    end

    it "stays displayed after the change is enabled even though uncategorized is disallowed" do
      SiteSetting.allow_uncategorized_topics = false
      SiteSetting.remove_and_replace_uncategorized = true
      expect(described_class.should_display_upcoming_change?).to eq(true)
    end
  end

  describe "hidden legacy settings" do
    # Declared via `hide_settings:` in the upcoming change metadata
    # (config/site_settings.yml) and resolved live by the framework.
    let(:legacy_settings) { %i[allow_uncategorized_topics suppress_uncategorized_badge] }

    it "hides the legacy uncategorized settings only while the change is enabled" do
      expect(SiteSetting.hidden_settings).not_to include(*legacy_settings)

      SiteSetting.remove_and_replace_uncategorized = true

      expect(SiteSetting.hidden_settings).to include(*legacy_settings)
    end
  end
end
