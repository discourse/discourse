# frozen_string_literal: true

describe DiscourseAi::Translation::TagCandidates do
  describe ".get" do
    it "returns all tags" do
      Fabricate(:tag)
      expect(DiscourseAi::Translation::TagCandidates.get.count).to eq(Tag.count)
    end

    context "when ai_translation_backfill_limit_to_public_content is enabled" do
      before { SiteSetting.ai_translation_backfill_limit_to_public_content = true }

      it "includes tags not in any tag group" do
        tag = Fabricate(:tag)

        tags = DiscourseAi::Translation::TagCandidates.get
        expect(tags).to include(tag)
      end

      it "includes tags in tag groups visible to everyone" do
        tag = Fabricate(:tag)
        tag_group = Fabricate(:tag_group, tags: [tag])
        TagGroupPermission.create!(
          tag_group: tag_group,
          group_id: Group::AUTO_GROUPS[:everyone],
          permission_type: TagGroupPermission.permission_types[:full],
        )

        tags = DiscourseAi::Translation::TagCandidates.get
        expect(tags).to include(tag)
      end

      it "excludes tags in tag groups not visible to everyone" do
        tag = Fabricate(:tag)
        tag_group = Fabricate(:tag_group, tags: [tag])
        # remove default everyone permission if exists
        TagGroupPermission.where(tag_group: tag_group).destroy_all
        # add restricted permission
        restricted_group = Fabricate(:group)
        TagGroupPermission.create!(
          tag_group: tag_group,
          group_id: restricted_group.id,
          permission_type: TagGroupPermission.permission_types[:full],
        )

        tags = DiscourseAi::Translation::TagCandidates.get
        expect(tags).not_to include(tag)
      end
    end
  end

  describe ".calculate_completion_per_locale" do
    before { Tag.destroy_all }

    context "when completion determined by tag's locale" do
      it "returns done = total if all tags are in the locale" do
        locale = "pt_BR"
        Fabricate(:tag, locale:)
        Fabricate(:tag, locale: "pt") # pt counts as pt_BR

        completion = DiscourseAi::Translation::TagCandidates.calculate_completion_per_locale(locale)
        expect(completion).to eq({ done: Tag.count, total: Tag.count })
      end

      it "returns correct done and total if some tags are in the locale" do
        locale = "pt_BR"
        Fabricate(:tag, locale:)
        Fabricate(:tag, locale: "ar") # not portuguese

        completion = DiscourseAi::Translation::TagCandidates.calculate_completion_per_locale(locale)
        expect(completion).to eq({ done: 1, total: Tag.count })
      end
    end

    context "when completion determined by tag localizations" do
      it "returns done = total if all tags have a localization in the locale" do
        locale = "pt_BR"
        tag1 = Fabricate(:tag, locale: "en")
        tag2 = Fabricate(:tag, locale: "en")
        Fabricate(:tag_localization, tag: tag1, locale:)
        Fabricate(:tag_localization, tag: tag2, locale: "pt") # pt counts as pt_BR

        completion = DiscourseAi::Translation::TagCandidates.calculate_completion_per_locale(locale)
        expect(completion).to eq({ done: Tag.count, total: Tag.count })
      end

      it "returns correct done and total if some tags have a localization in the locale" do
        locale = "es"
        tag1 = Fabricate(:tag, locale: "en")
        tag2 = Fabricate(:tag, locale: "fr")
        Fabricate(:tag_localization, tag: tag1, locale:)
        Fabricate(:tag_localization, tag: tag2, locale: "ar") # not the target locale

        completion = DiscourseAi::Translation::TagCandidates.calculate_completion_per_locale(locale)
        expect(completion).to eq({ done: 1, total: Tag.count })
      end
    end

    it "returns correct done and total based on both tag.locale and TagLocalization" do
      locale = "pt_BR"

      # translated candidates
      Fabricate(:tag, locale:)
      tag2 = Fabricate(:tag, locale: "en")
      Fabricate(:tag_localization, tag: tag2, locale:)

      # untranslated candidate
      tag3 = Fabricate(:tag, locale: "fr")
      Fabricate(:tag_localization, tag: tag3, locale: "zh_CN")

      completion = DiscourseAi::Translation::TagCandidates.calculate_completion_per_locale(locale)
      translated_candidates = 2
      total_candidates = Tag.count
      expect(completion).to eq({ done: translated_candidates, total: total_candidates })
    end

    it "does not allow done to exceed total when tag.locale and tag_localization both exist" do
      locale = "pt_BR"
      tag = Fabricate(:tag, locale:)
      Fabricate(:tag_localization, tag:, locale:)

      completion = DiscourseAi::Translation::TagCandidates.calculate_completion_per_locale(locale)
      expect(completion).to eq({ done: Tag.count, total: Tag.count })
    end

    it "returns 0 for done and total when no tags are present" do
      completion = DiscourseAi::Translation::TagCandidates.calculate_completion_per_locale("pt")
      expect(completion).to eq({ done: 0, total: 0 })
    end
  end
end
