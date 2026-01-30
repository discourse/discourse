# frozen_string_literal: true

describe TagSettingsUpdater do
  fab!(:admin)
  fab!(:tag)

  describe "#update" do
    it "updates basic tag attributes" do
      result = TagSettingsUpdater.update(tag, admin, { name: "new-name", description: "new desc" })

      expect(result).to eq(true)
      tag.reload
      expect(tag.name).to eq("new-name")
      expect(tag.description).to eq("new desc")
    end

    it "updates slug when provided" do
      result = TagSettingsUpdater.update(tag, admin, { slug: "custom-slug" })

      expect(result).to eq(true)
      expect(tag.reload.slug).to eq("custom-slug")
    end

    it "cleans tag name using DiscourseTagging" do
      result = TagSettingsUpdater.update(tag, admin, { name: "  New Name  " })

      expect(result).to eq(true)
      expect(tag.reload.name).to eq("new-name")
    end

    it "returns false and populates errors when save fails" do
      existing_tag = Fabricate(:tag)
      updater = TagSettingsUpdater.new(tag, admin)
      result = updater.update({ name: existing_tag.name })

      expect(result).to eq(false)
      expect(updater.errors).to be_present
    end

    it "logs staff action when name changes" do
      old_name = tag.name

      expect { TagSettingsUpdater.update(tag, admin, { name: "renamed-tag" }) }.to change {
        UserHistory.where(
          acting_user_id: admin.id,
          custom_type: "renamed_tag",
          previous_value: old_name,
          new_value: "renamed-tag",
        ).count
      }.by(1)
    end

    it "does not log staff action when name stays the same" do
      expect { TagSettingsUpdater.update(tag, admin, { description: "new desc" }) }.not_to change {
        UserHistory.where(acting_user_id: admin.id, custom_type: "renamed_tag").count
      }
    end

    context "with synonyms" do
      fab!(:synonym1) { Fabricate(:tag, target_tag: tag) }
      fab!(:synonym2) { Fabricate(:tag, target_tag: tag) }
      fab!(:other_tag, :tag)

      it "removes synonyms when removed_synonym_ids provided" do
        TagSettingsUpdater.update(tag, admin, { removed_synonym_ids: [synonym1.id] })

        expect(synonym1.reload.target_tag_id).to be_nil
        expect(synonym2.reload.target_tag_id).to eq(tag.id)
      end

      it "adds existing tags as synonyms" do
        TagSettingsUpdater.update(
          tag,
          admin,
          { new_synonyms: [{ id: other_tag.id, name: other_tag.name }] },
        )

        expect(other_tag.reload.target_tag_id).to eq(tag.id)
      end

      it "only removes synonyms that belong to this tag" do
        unrelated_synonym = Fabricate(:tag, target_tag: other_tag)

        TagSettingsUpdater.update(tag, admin, { removed_synonym_ids: [unrelated_synonym.id] })

        expect(unrelated_synonym.reload.target_tag_id).to eq(other_tag.id)
      end
    end

    context "with transaction rollback" do
      it "rolls back all changes if tag save fails" do
        synonym = Fabricate(:tag, target_tag: tag)
        other_tag = Fabricate(:tag)

        tag.stubs(:save).returns(false)
        tag.errors.add(:name, "is invalid")

        updater = TagSettingsUpdater.new(tag, admin)
        result =
          updater.update(
            {
              name: "new-name",
              removed_synonym_ids: [synonym.id],
              new_synonyms: [{ id: other_tag.id, name: other_tag.name }],
            },
          )

        expect(result).to eq(false)
        expect(synonym.reload.target_tag_id).to eq(tag.id)
        expect(other_tag.reload.target_tag_id).to be_nil
      end
    end

    context "with localizations" do
      it "creates new localizations" do
        TagSettingsUpdater.update(
          tag,
          admin,
          { localizations: [{ locale: "de", name: "German Name", description: "German Desc" }] },
        )

        loc = TagLocalization.find_by(tag_id: tag.id, locale: "de")
        expect(loc).to be_present
        expect(loc.name).to eq("German Name")
        expect(loc.description).to eq("German Desc")
      end

      it "updates existing localizations" do
        TagLocalization.create!(tag_id: tag.id, locale: "fr", name: "Old", description: "Old Desc")

        TagSettingsUpdater.update(
          tag,
          admin,
          { localizations: [{ locale: "fr", name: "New", description: "New Desc" }] },
        )

        loc = TagLocalization.find_by(tag_id: tag.id, locale: "fr")
        expect(loc.name).to eq("New")
        expect(loc.description).to eq("New Desc")
      end

      it "removes localizations not in the submitted list" do
        TagLocalization.create!(tag_id: tag.id, locale: "es", name: "Spanish", description: "")
        TagLocalization.create!(tag_id: tag.id, locale: "it", name: "Italian", description: "")

        TagSettingsUpdater.update(
          tag,
          admin,
          { localizations: [{ locale: "es", name: "Spanish Updated", description: "" }] },
        )

        expect(TagLocalization.find_by(tag_id: tag.id, locale: "es")).to be_present
        expect(TagLocalization.find_by(tag_id: tag.id, locale: "it")).to be_nil
      end
    end
  end

  describe "#updated_tag" do
    it "returns tag with associations preloaded" do
      synonym = Fabricate(:tag, target_tag: tag)
      updater = TagSettingsUpdater.new(tag, admin)
      updater.update({ name: "updated" })

      updated = updater.updated_tag

      expect(updated.name).to eq("updated")
      expect(updated.association(:synonyms).loaded?).to eq(true)
      expect(updated.association(:localizations).loaded?).to eq(true)
      expect(updated.association(:tag_groups).loaded?).to eq(true)
    end
  end
end
