# frozen_string_literal: true

RSpec.describe(Tags::Search) do
  describe described_class::Contract, type: :model do
    it "accepts a blank or in-range limit" do
      [nil, 0, 3, SiteSetting.max_tag_search_results].each do |limit|
        expect(described_class.new(limit:)).to be_valid
      end
    end

    it "rejects malformed or out-of-range limits" do
      [-1, "abc", SiteSetting.max_tag_search_results + 1].each do |limit|
        contract = described_class.new(limit:)
        expect(contract).to be_invalid
        expect(contract.errors[:limit]).to be_present
      end
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)
    fab!(:tag1) { Fabricate(:tag, name: "alpha") }
    fab!(:tag2) { Fabricate(:tag, name: "beta") }

    let(:params) { { q: "alpha" } }
    let(:dependencies) { { guardian: Guardian.new(user) } }

    before { SiteSetting.tagging_enabled = true }

    context "when contract is invalid" do
      let(:params) { { q: "test", limit: -1 } }

      it { is_expected.to fail_a_contract }
    end

    context "when everything's ok" do
      it "returns matching tags without a forbidden result" do
        expect(result).to run_successfully
        expect(result[:tags].map { |tag| tag[:name] }).to contain_exactly("alpha")
        expect(result[:forbidden]).to be_nil
        expect(result[:forbidden_message]).to be_nil
      end
    end

    context "with blank query" do
      let(:params) { {} }

      it "returns tags for the blank query" do
        expect(result).to run_successfully
        expect(result[:tags]).to be_present
      end
    end

    context "with prioritizeRecentTags on the blank composer dropdown" do
      fab!(:popular_tag) { Fabricate(:tag, name: "popular", public_topic_count: 100) }
      fab!(:recent_tag_a) { Fabricate(:tag, name: "recenta") }
      fab!(:recent_tag_b) { Fabricate(:tag, name: "recentb") }

      let(:params) { { prioritizeRecentTags: true, filterForInput: true } }

      before { SiteSetting.prioritize_recently_used_tags = true }

      def tag_names(call_params, guardian: Guardian.new(user))
        described_class.call(params: call_params, guardian:)[:tags].map { |tag| tag[:name] }
      end

      it "surfaces tags from the user's recent topics first, most recently used first" do
        Fabricate(:topic, user: user, tags: [recent_tag_a])
        Fabricate(:topic, user: user, tags: [recent_tag_b])

        names = tag_names(params)
        expect(names.first(2)).to eq(%w[recentb recenta])
        expect(names.index("recentb")).to be < names.index("popular")
      end

      it "uses popularity ordering when recent-tag prioritization is unavailable" do
        SiteSetting.prioritize_recently_used_tags = false
        Fabricate(:topic, user: user, tags: [recent_tag_a])

        expect(tag_names(params).first).to eq("popular")

        SiteSetting.prioritize_recently_used_tags = true
        expect(tag_names(params, guardian: Guardian.new).first).to eq("popular")
      end

      it "does not reorder once the user starts typing a term" do
        Fabricate(:topic, user: user, tags: [recent_tag_a])
        Fabricate(:topic, user: user, tags: [recent_tag_b])

        expect(tag_names(params.merge(q: "recent"))).to eq(%w[recenta recentb])
      end
    end

    context "with a category" do
      fab!(:category)

      let(:params) { { q: "alpha", categoryId: category.id } }

      it "returns tags filtered for the category" do
        expect(result).to run_successfully
        expect(result[:tags].map { |tag| tag[:name] }).to contain_exactly("alpha")
      end
    end

    context "with a non-existent category" do
      let(:params) { { q: "alpha", categoryId: -999 } }

      it "treats a non-existent category as no category filter" do
        expect(result).to run_successfully
        expect(result[:tags].map { |tag| tag[:name] }).to contain_exactly("alpha")
      end
    end

    context "with filterForInput returning disabled tags for one_per_topic groups" do
      fab!(:tag3) { Fabricate(:tag, name: "gamma") }
      fab!(:tag_group) do
        Fabricate(:tag_group, name: "Exclusive Group", one_per_topic: true, tags: [tag1, tag3])
      end

      let(:params) { { q: "gamma", filterForInput: true, selected_tags: [tag1.name] } }

      it "returns the excluded tag with its conflicting tag in the reason" do
        expect(result).to run_successfully

        expect(result[:tags].find { |tag| tag[:name] == "gamma" }).to include(
          disabled: true,
          title:
            I18n.t(
              "tags.forbidden.one_tag_per_topic_group",
              tag_group_name: tag_group.name,
              tag_names: tag1.name,
            ),
        )
      end
    end

    context "with a hidden selected tag in a one_per_topic group" do
      fab!(:staff_group) { Group[:staff] }
      fab!(:private_category) { Fabricate(:private_category, group: staff_group) }
      fab!(:hidden_selected_tag) { Fabricate(:tag, name: "secret-selected") }
      fab!(:public_sibling_tag) { Fabricate(:tag, name: "public-sibling") }
      fab!(:tag_group) do
        Fabricate(
          :tag_group,
          name: "Exclusive Group",
          one_per_topic: true,
          tags: [hidden_selected_tag, public_sibling_tag],
        )
      end

      before { CategoryTag.create!(category: private_category, tag: hidden_selected_tag) }

      let(:params) do
        { q: "public", filterForInput: true, selected_tag_ids: [hidden_selected_tag.id] }
      end

      it "uses a generic one_per_topic reason instead of leaking the hidden selected tag name" do
        disabled = result[:tags].find { |tag| tag[:name] == "public-sibling" && tag[:disabled] }
        expect(disabled).to include(
          disabled: true,
          title: I18n.t("tags.forbidden.one_tag_per_topic_group_without_names"),
        )
      end
    end

    context "with filterForInput returning disabled tags for missing parent tag" do
      fab!(:parent_tag) { Fabricate(:tag, name: "parent") }
      fab!(:child_tag) { Fabricate(:tag, name: "childtag") }
      fab!(:tag_group) do
        Fabricate(:tag_group, name: "Child Group", parent_tag:, tags: [child_tag])
      end

      let(:params) { { q: "childtag", filterForInput: true } }

      it "disables the child tag with a missing-parent reason" do
        expect(result).to run_successfully
        child = result[:tags].find { |tag| tag[:name] == child_tag.name }

        expect(child).to include(
          disabled: true,
          title:
            I18n.t(
              "tags.forbidden.missing_parent_tag",
              parent_tag_name: parent_tag.name,
              tag_group_name: tag_group.name,
            ),
        )
      end

      it "does not surface the tag when the term only matches mid-word" do
        result =
          described_class.call(params: { q: "hildtag", filterForInput: true }, **dependencies)
        expect(result[:tags].map { |tag| tag[:name] }).not_to include("childtag")
      end
    end

    context "with filterForInput returning disabled tags for category restrictions" do
      fab!(:category)
      fab!(:restricted_tag) { Fabricate(:tag, name: "restricted") }

      before { CategoryTag.create!(category:, tag: restricted_tag) }

      let(:params) { { q: "restricted", filterForInput: true } }

      it "disables the tag with the category restriction reason" do
        expect(result).to run_successfully
        expect(result[:tags].find { |tag| tag[:name] == restricted_tag.name }).to include(
          disabled: true,
          title:
            I18n.t(
              "tags.forbidden.restricted_to",
              count: 1,
              tag_name: restricted_tag.name,
              category_names: category.name,
            ),
        )
      end
    end

    context "with a tag restricted to more than three accessible categories" do
      fab!(:category_a) { Fabricate(:category, name: "Category A") }
      fab!(:category_b) { Fabricate(:category, name: "Category B") }
      fab!(:category_c) { Fabricate(:category, name: "Category C") }
      fab!(:category_d) { Fabricate(:category, name: "Category D") }
      fab!(:restricted_tag) { Fabricate(:tag, name: "many-categories") }

      before do
        [category_a, category_b, category_c, category_d].each do |category|
          CategoryTag.create!(category:, tag: restricted_tag)
        end
      end

      let(:params) { { q: restricted_tag.name, filterForInput: true } }

      it "lists three category names and the number of additional categories" do
        visible_category_names = [category_a, category_b, category_c, category_d].map(&:name).sort
        expected_reason =
          I18n.t(
            "tags.forbidden.restricted_to_truncated",
            tag_name: restricted_tag.name,
            category_names: visible_category_names.first(3).join(", "),
            more_count: 1,
          )

        expect(result[:tags].find { |tag| tag[:name] == restricted_tag.name }).to include(
          disabled: true,
          title: expected_reason,
        )
      end
    end

    context "with a tag restricted to a category the user cannot access (via CategoryTag)" do
      fab!(:staff_group) { Group[:staff] }
      fab!(:private_category) { Fabricate(:private_category, group: staff_group) }
      fab!(:secret_tag) { Fabricate(:tag, name: "bots-gone-mad") }

      before { CategoryTag.create!(category: private_category, tag: secret_tag) }

      let(:params) { { q: "bots", filterForInput: true } }

      it "hides the tag from users without access" do
        expect(result[:tags].map { |tag| tag[:name] }).not_to include(secret_tag.name)
      end

      it "shows the tag to admins" do
        admin = Fabricate(:admin)
        admin_result = described_class.call(params:, guardian: Guardian.new(admin))
        expect(admin_result[:tags].map { |tag| tag[:name] }).to include(secret_tag.name)
      end

      it "shows the tag to users who can access the category" do
        staff = Fabricate(:user)
        staff_group.add(staff)
        staff_result = described_class.call(params:, guardian: Guardian.new(staff))
        expect(staff_result[:tags].map { |tag| tag[:name] }).to include(secret_tag.name)
      end

      it "shows the tag when it is also attached to a category the user can access" do
        public_category = Fabricate(:category)
        CategoryTag.create!(category: public_category, tag: secret_tag)
        expect(result[:tags].map { |tag| tag[:name] }).to include(secret_tag.name)
      end
    end

    context "with a tag restricted to a category the user cannot access (via CategoryTagGroup)" do
      fab!(:staff_group) { Group[:staff] }
      fab!(:private_category) { Fabricate(:private_category, group: staff_group) }
      fab!(:secret_tag) { Fabricate(:tag, name: "insider-info") }
      fab!(:tag_group) { Fabricate(:tag_group, name: "Insider", tags: [secret_tag]) }

      before { CategoryTagGroup.create!(category: private_category, tag_group: tag_group) }

      let(:params) { { q: "insider", filterForInput: true } }

      it "does not return the tag restricted by its group" do
        expect(result[:tags].map { |tag| tag[:name] }).not_to include(secret_tag.name)
      end
    end

    context "when searching without filterForInput for a tag restricted to an inaccessible category" do
      fab!(:staff_group) { Group[:staff] }
      fab!(:private_category) { Fabricate(:private_category, group: staff_group) }
      fab!(:secret_tag) { Fabricate(:tag, name: "bots-gone-mad") }

      before { CategoryTag.create!(category: private_category, tag: secret_tag) }

      let(:params) { { q: "bots" } }

      it "does not return the tag as an allowed result" do
        expect(result[:tags].map { |tag| tag[:name] }).not_to include(secret_tag.name)
      end
    end

    context "with a categoryId pointing to a category the user cannot see" do
      fab!(:staff_group) { Group[:staff] }
      fab!(:private_category) { Fabricate(:private_category, group: staff_group) }
      fab!(:restricted_tag) { Fabricate(:tag, name: "restricted-tag") }
      fab!(:global_tag) { Fabricate(:tag, name: "alpha-global") }

      before { CategoryTag.create!(category: private_category, tag: restricted_tag) }

      let(:params) { { q: "alpha-global", categoryId: private_category.id } }

      it "behaves as if the category did not exist" do
        expect(result).to run_successfully
        missing_category_result =
          described_class.call(params: { q: global_tag.name, categoryId: -999 }, **dependencies)

        expect(result[:tags]).to eq(missing_category_result[:tags])
      end
    end

    context "with excludeHasSynonyms" do
      fab!(:target_with_syn) { Fabricate(:tag, name: "maintag2") }
      fab!(:its_syn) { Fabricate(:tag, name: "syn-for-main", target_tag: target_with_syn) }

      let(:params) { { q: "maintag2", filterForInput: true, excludeHasSynonyms: true } }

      it "disables the tag with a reason" do
        expect(result[:tags].find { |tag| tag[:name] == target_with_syn.name }).to include(
          disabled: true,
          title: I18n.t("tags.forbidden.has_synonyms", tag_name: target_with_syn.name),
        )
      end
    end

    context "with an anonymous guardian" do
      fab!(:staff_group) { Group[:staff] }
      fab!(:private_category) { Fabricate(:private_category, group: staff_group) }
      fab!(:secret_tag) { Fabricate(:tag, name: "anon-secret") }

      before { CategoryTag.create!(category: private_category, tag: secret_tag) }

      let(:dependencies) { { guardian: Guardian.new } }
      let(:params) { { q: "anon-secret", filterForInput: true } }

      it "does not return tags restricted to inaccessible categories" do
        expect(result[:tags].map { |tag| tag[:name] }).not_to include(secret_tag.name)
      end
    end

    context "with a global tag disabled inside a category that disallows globals" do
      fab!(:strict_category) do
        Fabricate(:category).tap do |category_record|
          category_record.update!(allow_global_tags: false)
          Fabricate(:tag_group, tags: [Fabricate(:tag, name: "strict-only")]).tap do |tg|
            CategoryTagGroup.create!(category: category_record, tag_group: tg)
          end
        end
      end
      fab!(:global_tag) { Fabricate(:tag, name: "truly-global") }

      let(:params) { { q: "truly-global", filterForInput: true, categoryId: strict_category.id } }

      it "explains that the global tag is unavailable in this category" do
        expect(result[:tags].find { |tag| tag[:name] == global_tag.name }).to include(
          disabled: true,
          title: I18n.t("tags.forbidden.in_this_category", tag_name: global_tag.name),
        )
      end
    end

    context "with a synonym whose target is restricted to an inaccessible category (output payload)" do
      fab!(:staff_group) { Group[:staff] }
      fab!(:private_category) { Fabricate(:private_category, group: staff_group) }
      fab!(:secret_target) { Fabricate(:tag, name: "payload-secret") }
      fab!(:public_synonym) { Fabricate(:tag, name: "payload-syn", target_tag: secret_target) }

      before { CategoryTag.create!(category: private_category, tag: secret_target) }

      let(:params) { { q: "payload-syn" } }

      it "omits the inaccessible target from the serialized payload" do
        expect(result[:tags].find { |tag| tag[:name] == public_synonym.name }).to include(
          target_tag: nil,
        )
      end
    end

    context "with a synonym whose target is restricted to an inaccessible category" do
      fab!(:staff_group) { Group[:staff] }
      fab!(:private_category) { Fabricate(:private_category, group: staff_group) }
      fab!(:secret_target) { Fabricate(:tag, name: "secret-target") }
      fab!(:public_synonym) { Fabricate(:tag, name: "public-syn", target_tag: secret_target) }

      before { CategoryTag.create!(category: private_category, tag: secret_target) }

      let(:params) { { q: "public-syn", filterForInput: true, excludeSynonyms: true } }

      it "does not expose the target in the disabled reason" do
        disabled = result[:tags].find { |tag| tag[:name] == public_synonym.name }
        expect(disabled).to include(disabled: true)
        expect(disabled[:title]).not_to include(secret_target.name)
      end
    end

    context "with a global tag disabled without category context" do
      fab!(:staff_group) { Group[:staff] }
      fab!(:private_category) { Fabricate(:private_category, group: staff_group) }
      fab!(:secret_parent) { Fabricate(:tag, name: "secret-parent2") }
      fab!(:orphan_tag) { Fabricate(:tag, name: "orphan-tag") }
      fab!(:tag_group) do
        Fabricate(:tag_group, name: "Orphans", parent_tag: secret_parent, tags: [orphan_tag])
      end

      before { CategoryTag.create!(category: private_category, tag: secret_parent) }

      let(:params) { { q: "orphan-tag", filterForInput: true } }

      it "uses the general restriction wording without category context" do
        expect(result[:tags].find { |tag| tag[:name] == orphan_tag.name }).to include(
          disabled: true,
          title: I18n.t("tags.forbidden.not_allowed", tag_name: orphan_tag.name),
        )
      end
    end

    context "with a missing parent tag that is restricted to an inaccessible category" do
      fab!(:staff_group) { Group[:staff] }
      fab!(:private_category) { Fabricate(:private_category, group: staff_group) }
      fab!(:secret_parent) { Fabricate(:tag, name: "secret-parent") }
      fab!(:child_tag) { Fabricate(:tag, name: "public-child") }
      fab!(:tag_group) do
        Fabricate(:tag_group, name: "Kids", parent_tag: secret_parent, tags: [child_tag])
      end

      before { CategoryTag.create!(category: private_category, tag: secret_parent) }

      let(:params) { { q: "public-child", filterForInput: true } }

      it "does not expose the parent in the disabled reason" do
        disabled = result[:tags].find { |tag| tag[:name] == child_tag.name }
        expect(disabled).to include(disabled: true)
        expect(disabled[:title]).not_to include(secret_parent.name)
      end
    end

    context "when a user types the exact name of a tag restricted to an inaccessible category" do
      fab!(:staff_group) { Group[:staff] }
      fab!(:private_category) { Fabricate(:private_category, group: staff_group) }
      fab!(:secret_tag) { Fabricate(:tag, name: "bots-gone-mad") }

      before { CategoryTag.create!(category: private_category, tag: secret_tag) }

      let(:params) { { q: "bots-gone-mad", filterForInput: true } }

      it "does not confirm the tag exists in results or the forbidden fields" do
        expect(result[:tags].map { |tag| tag[:name] }).not_to include(secret_tag.name)
        expect(result[:forbidden]).to be_nil
        expect(result[:forbidden_message]).to be_nil
      end
    end

    context "with a mix of allowed and disabled matches" do
      fab!(:blocked_sibling) { Fabricate(:tag, name: "alphablocked") }
      fab!(:tag_group) do
        Fabricate(
          :tag_group,
          name: "Exclusive Group",
          one_per_topic: true,
          tags: [tag2, blocked_sibling],
        )
      end

      let(:params) { { q: "alpha", filterForInput: true, selected_tags: [tag2.name] } }

      it "lists allowed tags before disabled tags" do
        expect(result[:tags].map { |tag| tag[:name] }).to eq(%w[alpha alphablocked])
      end
    end

    context "when allowed tags are cut off by the limit" do
      fab!(:tag_foo1) { Fabricate(:tag, name: "foomatch1") }
      fab!(:tag_foo2) { Fabricate(:tag, name: "foomatch2") }

      let(:params) { { q: "foomatch", filterForInput: true, limit: 1 } }

      it "does not mislabel allowed tags as disabled" do
        disabled = result[:tags].select { |tag| tag[:disabled] }
        expect(disabled).to be_empty
      end
    end

    context "when an exact-match allowed tag is cut off by the limit" do
      fab!(:tag_exact) { Fabricate(:tag, name: "exacthit") }
      fab!(:tag_noise1) { Fabricate(:tag, name: "aexacthit") }
      fab!(:tag_noise2) { Fabricate(:tag, name: "bexacthit") }

      let(:params) { { q: "exacthit", filterForInput: true, limit: 1 } }

      it "does not mark an allowed tag as forbidden" do
        expect(result[:forbidden]).to be_nil
        expect(result[:forbidden_message]).to be_nil
      end
    end

    context "when a forbidden tag is detected" do
      fab!(:target_tag) { Fabricate(:tag, name: "maintag") }
      fab!(:synonym_tag) { Fabricate(:tag, name: "syntag", target_tag:) }

      let(:params) { { q: "syntag", excludeSynonyms: true } }

      it "returns the forbidden query and its synonym reason" do
        expect(result).to run_successfully
        expect(result[:forbidden]).to eq("syntag")
        expect(result[:forbidden_message]).to eq(
          I18n.t("tags.forbidden.synonym", tag_name: target_tag.name),
        )
      end
    end

    context "with a tag only used in personal messages" do
      fab!(:category)
      fab!(:pm_only_tag) { Fabricate(:tag, name: "pmonly", pm_topic_count: 1) }

      let(:params) { { q: "pmonly", categoryId: category.id, filterForInput: true, limit: 5 } }

      before { SiteSetting.display_personal_messages_tag_counts = true }

      it "keeps the tag selectable without exposing its PM count" do
        row = result[:tags].find { |tag| tag[:name] == "pmonly" }
        expect(row).to be_present
        expect(row[:disabled]).to be_blank
        expect(result[:forbidden]).to be_nil
        expect(result[:forbidden_message]).to be_nil
        expect(row).not_to have_key(:pm_count)
      end
    end

    context "when a hidden tag does not leak via forbidden" do
      fab!(:hidden_tag) { Fabricate(:tag, name: "secrethidden") }

      before { create_hidden_tags(%w[secrethidden]) }

      let(:params) { { q: "secrethidden" } }

      it "does not expose a hidden tag in results or as forbidden" do
        expect(result).to run_successfully
        expect(result[:forbidden]).to be_nil
        expect(result[:forbidden_message]).to be_nil
        expect(result[:tags].map { |tag| tag[:name] }).not_to include(hidden_tag.name)
      end
    end

    context "with required_tag_group propagation" do
      fab!(:required_tag_group, :tag_group) do
        Fabricate(:tag_group, name: "Required Group", tags: [tag1])
      end
      fab!(:required_category, :category)

      before do
        CategoryRequiredTagGroup.create!(
          category: required_category,
          tag_group: required_tag_group,
          min_count: 1,
        )
      end

      let(:params) { { filterForInput: true, categoryId: required_category.id } }

      it "propagates the required_tag_group from the filter context" do
        expect(result).to run_successfully
        expect(result[:required_tag_group]).to include(name: required_tag_group.name, min_count: 1)
      end
    end

    context "with an unsatisfied required tag group" do
      fab!(:app_tag) { Fabricate(:tag, name: "app-desktop") }
      fab!(:hosting_tag1) { Fabricate(:tag, name: "server-default-cloud") }
      fab!(:hosting_tag2) { Fabricate(:tag, name: "server-other-cloud") }
      fab!(:app_tag_group) { Fabricate(:tag_group, name: "Apps", tags: [app_tag]) }
      fab!(:hosting_tag_group) do
        Fabricate(:tag_group, name: "Hosting", tags: [hosting_tag1, hosting_tag2])
      end
      fab!(:required_category, :category)
      fab!(:otherwise_allowed_tag) { Fabricate(:tag, name: "os-linux") }
      fab!(:restricted_category) { Fabricate(:category, name: "Other category") }
      fab!(:restricted_tag) { Fabricate(:tag, name: "other-only") }

      before do
        CategoryRequiredTagGroup.create!(
          category: required_category,
          tag_group: app_tag_group,
          min_count: 1,
          order: 1,
        )
        CategoryRequiredTagGroup.create!(
          category: required_category,
          tag_group: hosting_tag_group,
          min_count: 2,
          order: 2,
        )
        CategoryTag.create!(category: restricted_category, tag: restricted_tag)
      end

      let(:params) do
        {
          q: "os-linux",
          filterForInput: true,
          categoryId: required_category.id,
          selected_tag_ids: [app_tag.id, hosting_tag1.id],
        }
      end

      it "explains how many more required-group tags are needed" do
        disabled = result[:tags].find { |tag| tag[:name] == otherwise_allowed_tag.name }

        expect(disabled[:disabled]).to be true
        expect(disabled[:title]).to eq(
          I18n.t(
            "tags.forbidden.required_tag_group",
            count: 1,
            tag_group_name: hosting_tag_group.name,
          ),
        )
      end

      it "keeps the category restriction reason for a genuinely restricted tag" do
        restricted_result =
          described_class.call(params: params.merge(q: restricted_tag.name), **dependencies)
        disabled = restricted_result[:tags].find { |tag| tag[:name] == restricted_tag.name }

        expect(disabled[:disabled]).to be true
        expect(disabled[:title]).to eq(
          I18n.t(
            "tags.forbidden.restricted_to",
            count: 1,
            tag_name: restricted_tag.name,
            category_names: restricted_category.name,
          ),
        )
      end

      it "allows other tags once the required group is satisfied" do
        satisfied_result =
          described_class.call(
            params: params.merge(selected_tag_ids: [app_tag.id, hosting_tag1.id, hosting_tag2.id]),
            **dependencies,
          )
        selectable = satisfied_result[:tags].find { |tag| tag[:name] == otherwise_allowed_tag.name }

        expect(selectable).to be_present
        expect(selectable[:disabled]).to be_blank
      end
    end

    context "with content localization enabled" do
      fab!(:strategy_tag) { Fabricate(:tag, name: "strategy", locale: "en") }
      fab!(:strategy_ja_localization) do
        Fabricate(:tag_localization, tag: strategy_tag, locale: "ja", name: "戦略")
      end

      let(:params) { { q: "戦" } }

      before do
        SiteSetting.content_localization_enabled = true
        SiteSetting.content_localization_supported_locales = "en|ja"
      end

      it "matches tags by their localized name in the current locale" do
        I18n.with_locale(:ja) do
          expect(result[:tags].map { |tag| tag[:name] }).to contain_exactly("戦略")
        end
      end

      it "does not match localizations from other locales" do
        I18n.with_locale(:en) { expect(result[:tags].map { |tag| tag[:name] }).to be_empty }
      end
    end
  end
end
