# frozen_string_literal: true

RSpec.describe SiteSetting::Action::RemoveAndReplaceUncategorizedToggled do
  let!(:uncategorized) { Category.find(SiteSetting.uncategorized_category_id) }

  def create_event(event_type, event_data = nil)
    UpcomingChangeEvent.create!(
      event_type:,
      upcoming_change_name: described_class::UPCOMING_CHANGE,
      event_data:,
    )
  end

  def snapshot(allow_uncategorized_topics:, default_composer_category: "")
    {
      allow_uncategorized_topics:,
      default_composer_category:,
      uncategorized_category_id: uncategorized.id,
    }
  end

  describe "enabling" do
    let!(:event) { create_event(:automatically_promoted) }

    it "demotes the special category in place, pins it as the composer default and exempts it from definition topics" do
      described_class.call(enabled: true)

      expect(SiteSetting.uncategorized_category_id).to eq(-1)
      expect(SiteSetting.allow_uncategorized_topics).to eq(false)
      expect(SiteSetting.default_composer_category).to eq(uncategorized.id.to_s)
      expect(uncategorized.reload.uncategorized?).to eq(false)
      expect(uncategorized.custom_fields[Category::SKIP_DEFINITION_CUSTOM_FIELD]).to eq(true)
    end

    it "does nothing without an opt-in or promotion event" do
      event.destroy!

      described_class.call(enabled: true)

      expect(SiteSetting.uncategorized_category_id).to eq(uncategorized.id)
    end

    it "leaves an explicit default_composer_category untouched" do
      other = Fabricate(:category)
      SiteSetting.default_composer_category = other.id.to_s

      described_class.call(enabled: true)

      expect(SiteSetting.default_composer_category).to eq(other.id.to_s)
    end

    it "snapshots the prior state onto the event, ignoring other events' data" do
      create_event(:status_changed, { previous_value: nil, new_value: "experimental" })

      described_class.call(enabled: true)

      expect(event.reload.event_data).to eq(
        "allow_uncategorized_topics" => true,
        "default_composer_category" => "",
        "uncategorized_category_id" => uncategorized.id,
      )
    end

    it "keeps the original snapshot on a later opt-in" do
      event.update!(event_data: snapshot(allow_uncategorized_topics: true))
      reopt_in = create_event(:manual_opt_in)

      described_class.call(enabled: true)

      expect(reopt_in.reload.event_data).to eq(nil)
    end

    it "keeps a category holding even a trashed topic, without pinning it as the composer default" do
      Fabricate(:topic, category: uncategorized).trash!
      SiteSetting.allow_uncategorized_topics = false

      described_class.call(enabled: true)

      expect(Category.exists?(uncategorized.id)).to eq(true)
      expect(SiteSetting.default_composer_category).to eq("")
    end

    context "when the site was not allowing uncategorized topics" do
      before { SiteSetting.allow_uncategorized_topics = false }

      it "removes the unused category instead of exposing it" do
        described_class.call(enabled: true)

        expect(Category.exists?(uncategorized.id)).to eq(false)
      end

      it "keeps a category an admin has renamed" do
        uncategorized.update!(name: "Lounge")

        described_class.call(enabled: true)

        expect(Category.exists?(uncategorized.id)).to eq(true)
      end

      it "keeps a category whose permissions were changed" do
        Fabricate(:category_group, category: uncategorized, group: Group[:staff])

        described_class.call(enabled: true)

        expect(Category.exists?(uncategorized.id)).to eq(true)
      end

      it "keeps a category that has subcategories" do
        event.update!(event_data: snapshot(allow_uncategorized_topics: false))
        SiteSetting.uncategorized_category_id = -1
        Fabricate(:category, parent_category: uncategorized)

        described_class.call(enabled: true)

        expect(Category.exists?(uncategorized.id)).to eq(true)
      end
    end
  end

  describe "disabling" do
    before do
      SiteSetting.uncategorized_category_id = -1
      SiteSetting.allow_uncategorized_topics = false
    end

    it "restores the special category and the prior settings from the snapshot" do
      create_event(
        :automatically_promoted,
        snapshot(
          allow_uncategorized_topics: true,
          default_composer_category: uncategorized.id.to_s,
        ),
      )
      uncategorized.upsert_custom_fields(Category::SKIP_DEFINITION_CUSTOM_FIELD => true)

      described_class.call(enabled: false)

      expect(SiteSetting.uncategorized_category_id).to eq(uncategorized.id)
      expect(SiteSetting.allow_uncategorized_topics).to eq(true)
      expect(SiteSetting.default_composer_category).to eq(uncategorized.id.to_s)
      expect(uncategorized.reload.custom_fields).not_to include(
        Category::SKIP_DEFINITION_CUSTOM_FIELD,
      )
    end

    it "does nothing when the site was not using uncategorized topics at opt-in" do
      create_event(:automatically_promoted, snapshot(allow_uncategorized_topics: false))

      described_class.call(enabled: false)

      expect(SiteSetting.uncategorized_category_id).to eq(-1)
    end

    it "does nothing when there is no snapshot" do
      described_class.call(enabled: false)

      expect(SiteSetting.uncategorized_category_id).to eq(-1)
    end

    it "does nothing when the demoted category has since been deleted" do
      create_event(:automatically_promoted, snapshot(allow_uncategorized_topics: true))
      uncategorized.delete

      described_class.call(enabled: false)

      expect(SiteSetting.uncategorized_category_id).to eq(-1)
    end
  end

  describe ".should_display_upcoming_change?" do
    it "is displayed while uncategorized topics are allowed or the change is enabled" do
      expect(described_class.should_display_upcoming_change?).to eq(true)

      SiteSetting.allow_uncategorized_topics = false
      SiteSetting.remove_and_replace_uncategorized = false
      expect(described_class.should_display_upcoming_change?).to eq(false)

      SiteSetting.remove_and_replace_uncategorized = true
      expect(described_class.should_display_upcoming_change?).to eq(true)
    end
  end
end
