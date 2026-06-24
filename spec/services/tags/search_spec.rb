# frozen_string_literal: true

RSpec.describe(Tags::Search) do
  describe described_class::Contract, type: :model do
    it "is valid with no limit" do
      expect(described_class.new(limit: nil)).to be_valid
    end

    it "is valid with a positive limit" do
      expect(described_class.new(limit: 3)).to be_valid
    end

    it "rejects a negative limit" do
      contract = described_class.new(limit: -1)
      expect(contract.valid?).to be false
      expect(contract.errors[:limit]).to be_present
    end

    it "rejects a non-numeric limit" do
      contract = described_class.new
      contract.assign_attributes(limit: "abc")
      expect(contract.valid?).to be false
      expect(contract.errors[:limit]).to be_present
    end

    it "rejects a limit exceeding max_tag_search_results" do
      contract = described_class.new(limit: SiteSetting.max_tag_search_results + 1)
      expect(contract.valid?).to be false
      expect(contract.errors[:limit]).to be_present
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
      it { is_expected.to run_successfully }

      it "returns matching tags" do
        expect(result[:tags].map { |t| t[:name] }).to include("alpha")
      end

      it "does not return non-matching tags" do
        expect(result[:tags].map { |t| t[:name] }).not_to include("beta")
      end

      it "sets forbidden to nil" do
        expect(result[:forbidden]).to be_nil
      end

      it "sets forbidden_message to nil" do
        expect(result[:forbidden_message]).to be_nil
      end
    end

    context "with blank query" do
      let(:params) { {} }

      it { is_expected.to run_successfully }

      it "returns tags ordered by popularity" do
        expect(result[:tags]).to be_present
      end
    end

    context "with a category" do
      fab!(:category)

      let(:params) { { q: "alpha", categoryId: category.id } }

      it { is_expected.to run_successfully }
    end

    context "with a non-existent category" do
      let(:params) { { q: "alpha", categoryId: -999 } }

      it { is_expected.to run_successfully }
    end

    context "with filterForInput returning disabled tags for one_per_topic groups" do
      fab!(:tag3) { Fabricate(:tag, name: "gamma") }
      fab!(:tag_group) do
        Fabricate(:tag_group, name: "Exclusive Group", one_per_topic: true, tags: [tag1, tag3])
      end

      let(:params) { { q: "gamma", filterForInput: true, selected_tags: [tag1.name] } }

      it { is_expected.to run_successfully }

      it "marks the excluded tag as disabled" do
        disabled = result[:tags].select { |t| t[:disabled] }
        expect(disabled.map { |t| t[:name] }).to include("gamma")
      end

      it "names the conflicting tag in the one_per_topic reason" do
        disabled = result[:tags].find { |t| t[:name] == "gamma" && t[:disabled] }
        expect(disabled[:title]).to eq(
          I18n.t("tags.forbidden.one_tag_per_topic_group", tag_names: "alpha"),
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
        expect(disabled).to be_present
        expect(disabled[:title]).not_to include(hidden_selected_tag.name)
        expect(disabled[:title]).to eq(
          I18n.t("tags.forbidden.one_tag_per_topic_group_without_names"),
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

      it { is_expected.to run_successfully }

      it "marks the child tag as disabled" do
        disabled = result[:tags].select { |t| t[:disabled] }
        expect(disabled.map { |t| t[:name] }).to include("childtag")
      end

      it "includes the missing parent tag reason" do
        disabled = result[:tags].find { |t| t[:name] == "childtag" && t[:disabled] }
        expect(disabled[:title]).to include("parent")
      end

      it "does not surface the tag when the term only matches mid-word" do
        result =
          described_class.call(params: { q: "hildtag", filterForInput: true }, **dependencies)
        expect(result[:tags].map { |t| t[:name] }).not_to include("childtag")
      end
    end

    context "with filterForInput returning disabled tags for category restrictions" do
      fab!(:category)
      fab!(:restricted_tag) { Fabricate(:tag, name: "restricted") }

      before { CategoryTag.create!(category:, tag: restricted_tag) }

      let(:params) { { q: "restricted", filterForInput: true } }

      it { is_expected.to run_successfully }

      it "marks the category-restricted tag as disabled" do
        disabled = result[:tags].select { |t| t[:disabled] }
        expect(disabled.map { |t| t[:name] }).to include("restricted")
      end

      it "includes the category name in the reason" do
        disabled = result[:tags].find { |t| t[:name] == "restricted" && t[:disabled] }
        expect(disabled[:title]).to include(category.name)
      end
    end

    context "with a tag restricted to a category the user cannot access (via CategoryTag)" do
      fab!(:staff_group) { Group[:staff] }
      fab!(:private_category) { Fabricate(:private_category, group: staff_group) }
      fab!(:secret_tag) { Fabricate(:tag, name: "bots-gone-mad") }

      before { CategoryTag.create!(category: private_category, tag: secret_tag) }

      let(:params) { { q: "bots", filterForInput: true } }

      it "does not leak the tag name to unauthorized users" do
        names = result[:tags].map { |t| t[:name] }
        expect(names).not_to include("bots-gone-mad")
      end

      it "still shows the tag to admins" do
        admin = Fabricate(:admin)
        admin_result =
          described_class.call(params:, **dependencies.merge(guardian: Guardian.new(admin)))
        expect(admin_result[:tags].map { |t| t[:name] }).to include("bots-gone-mad")
      end

      it "still shows the tag to users who can access the category" do
        staff = Fabricate(:user)
        staff_group.add(staff)
        staff_result =
          described_class.call(params:, **dependencies.merge(guardian: Guardian.new(staff)))
        expect(staff_result[:tags].map { |t| t[:name] }).to include("bots-gone-mad")
      end

      it "still shows the tag when it is also attached to a category the user can access" do
        public_category = Fabricate(:category)
        CategoryTag.create!(category: public_category, tag: secret_tag)
        names = result[:tags].map { |t| t[:name] }
        expect(names).to include("bots-gone-mad")
      end
    end

    context "with a tag restricted to a category the user cannot access (via CategoryTagGroup)" do
      fab!(:staff_group) { Group[:staff] }
      fab!(:private_category) { Fabricate(:private_category, group: staff_group) }
      fab!(:secret_tag) { Fabricate(:tag, name: "insider-info") }
      fab!(:tag_group) { Fabricate(:tag_group, name: "Insider", tags: [secret_tag]) }

      before { CategoryTagGroup.create!(category: private_category, tag_group: tag_group) }

      let(:params) { { q: "insider", filterForInput: true } }

      it "does not leak the tag name to unauthorized users" do
        names = result[:tags].map { |t| t[:name] }
        expect(names).not_to include("insider-info")
      end
    end

    context "when searching without filterForInput for a tag restricted to an inaccessible category" do
      fab!(:staff_group) { Group[:staff] }
      fab!(:private_category) { Fabricate(:private_category, group: staff_group) }
      fab!(:secret_tag) { Fabricate(:tag, name: "bots-gone-mad") }

      before { CategoryTag.create!(category: private_category, tag: secret_tag) }

      let(:params) { { q: "bots" } }

      it "does not leak the tag name as an allowed result" do
        expect(result[:tags].map { |t| t[:name] }).not_to include("bots-gone-mad")
      end
    end

    context "with a categoryId pointing to a category the user cannot see" do
      fab!(:staff_group) { Group[:staff] }
      fab!(:private_category) { Fabricate(:private_category, group: staff_group) }
      fab!(:restricted_tag) { Fabricate(:tag, name: "restricted-tag") }
      fab!(:global_tag) { Fabricate(:tag, name: "alpha-global") }

      before { CategoryTag.create!(category: private_category, tag: restricted_tag) }

      let(:params) { { q: "alpha-global", categoryId: private_category.id } }

      it "behaves as if the category did not exist (no enumeration vector)" do
        blind =
          described_class.call(params: { q: "alpha-global", categoryId: -999 }, **dependencies)
        expect(result[:tags].map { |t| t[:name] }).to eq(blind[:tags].map { |t| t[:name] })
      end
    end

    context "with excludeHasSynonyms" do
      fab!(:target_with_syn) { Fabricate(:tag, name: "maintag2") }
      fab!(:its_syn) { Fabricate(:tag, name: "syn-for-main", target_tag: target_with_syn) }

      let(:params) { { q: "maintag2", filterForInput: true, excludeHasSynonyms: true } }

      it "marks the tag as disabled with a synonyms reason" do
        disabled = result[:tags].find { |t| t[:name] == "maintag2" && t[:disabled] }
        expect(disabled).to be_present
        expect(disabled[:title]).to include("synonyms")
      end
    end

    context "with an anonymous guardian" do
      fab!(:staff_group) { Group[:staff] }
      fab!(:private_category) { Fabricate(:private_category, group: staff_group) }
      fab!(:secret_tag) { Fabricate(:tag, name: "anon-secret") }

      before { CategoryTag.create!(category: private_category, tag: secret_tag) }

      let(:dependencies) { { guardian: Guardian.new } }
      let(:params) { { q: "anon-secret", filterForInput: true } }

      it "does not leak tags restricted to inaccessible categories" do
        names = result[:tags].map { |t| t[:name] }
        expect(names).not_to include("anon-secret")
      end
    end

    context "with an admin guardian" do
      fab!(:staff_group) { Group[:staff] }
      fab!(:private_category) { Fabricate(:private_category, group: staff_group) }
      fab!(:secret_tag) { Fabricate(:tag, name: "admin-visible") }

      before { CategoryTag.create!(category: private_category, tag: secret_tag) }

      let(:dependencies) { { guardian: Guardian.new(Fabricate(:admin)) } }
      let(:params) { { q: "admin-visible" } }

      it "sees tags restricted to any category" do
        expect(result[:tags].map { |t| t[:name] }).to include("admin-visible")
      end
    end

    context "with a global tag disabled inside a category that disallows globals" do
      fab!(:strict_category) do
        Fabricate(:category).tap do |c|
          c.update!(allow_global_tags: false)
          Fabricate(:tag_group, tags: [Fabricate(:tag, name: "strict-only")]).tap do |tg|
            CategoryTagGroup.create!(category: c, tag_group: tg)
          end
        end
      end
      fab!(:global_tag) { Fabricate(:tag, name: "truly-global") }

      let(:params) { { q: "truly-global", filterForInput: true, categoryId: strict_category.id } }

      it "uses the 'in this category' fallback wording" do
        disabled = result[:tags].find { |t| t[:name] == "truly-global" && t[:disabled] }
        expect(disabled).to be_present
        expect(disabled[:title]).to include("this category")
      end
    end

    context "with a synonym whose target is restricted to an inaccessible category (output payload)" do
      fab!(:staff_group) { Group[:staff] }
      fab!(:private_category) { Fabricate(:private_category, group: staff_group) }
      fab!(:secret_target) { Fabricate(:tag, name: "payload-secret") }
      fab!(:public_synonym) { Fabricate(:tag, name: "payload-syn", target_tag: secret_target) }

      before { CategoryTag.create!(category: private_category, tag: secret_target) }

      let(:params) { { q: "payload-syn" } }

      it "does not leak the target tag name in the serialized payload" do
        entry = result[:tags].find { |t| t[:name] == "payload-syn" }
        expect(entry).to be_present
        expect(entry[:target_tag]).to be_nil
      end
    end

    context "with a synonym whose target is restricted to an inaccessible category" do
      fab!(:staff_group) { Group[:staff] }
      fab!(:private_category) { Fabricate(:private_category, group: staff_group) }
      fab!(:secret_target) { Fabricate(:tag, name: "secret-target") }
      fab!(:public_synonym) { Fabricate(:tag, name: "public-syn", target_tag: secret_target) }

      before { CategoryTag.create!(category: private_category, tag: secret_target) }

      let(:params) { { q: "public-syn", filterForInput: true, excludeSynonyms: true } }

      it "does not leak the target tag name in the disabled reason" do
        disabled = result[:tags].find { |t| t[:name] == "public-syn" && t[:disabled] }
        expect(disabled).to be_present
        expect(disabled[:title]).not_to include("secret-target")
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

      it "does not mention 'this category' when there is no category context" do
        disabled = result[:tags].find { |t| t[:name] == "orphan-tag" && t[:disabled] }
        expect(disabled).to be_present
        expect(disabled[:title]).not_to include("this category")
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

      it "does not leak the parent tag name in the disabled reason" do
        disabled = result[:tags].find { |t| t[:name] == "public-child" && t[:disabled] }
        expect(disabled).to be_present
        expect(disabled[:title]).not_to include("secret-parent")
      end
    end

    context "when a user types the exact name of a tag restricted to an inaccessible category" do
      fab!(:staff_group) { Group[:staff] }
      fab!(:private_category) { Fabricate(:private_category, group: staff_group) }
      fab!(:secret_tag) { Fabricate(:tag, name: "bots-gone-mad") }

      before { CategoryTag.create!(category: private_category, tag: secret_tag) }

      let(:params) { { q: "bots-gone-mad", filterForInput: true } }

      it "does not confirm the tag exists via forbidden_message" do
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
        names = result[:tags].map { |t| t[:name] }
        expect(names).to include("alpha", "alphablocked")
        expect(names.index("alpha")).to be < names.index("alphablocked")
      end
    end

    context "when allowed tags are cut off by the limit" do
      fab!(:tag_foo1) { Fabricate(:tag, name: "foomatch1") }
      fab!(:tag_foo2) { Fabricate(:tag, name: "foomatch2") }

      let(:params) { { q: "foomatch", filterForInput: true, limit: 1 } }

      it "does not mislabel allowed tags as disabled" do
        disabled = result[:tags].select { |t| t[:disabled] }
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

      it { is_expected.to run_successfully }

      it "sets forbidden to the search query" do
        expect(result[:forbidden]).to eq("syntag")
      end

      it "sets forbidden_message explaining the synonym" do
        expect(result[:forbidden_message]).to include("maintag")
      end
    end

    context "when the forbidden tag is already in results" do
      let(:params) { { q: "alpha" } }

      it "does not set forbidden" do
        expect(result[:forbidden]).to be_nil
      end
    end

    context "when a hidden tag does not leak via forbidden" do
      fab!(:hidden_tag) { Fabricate(:tag, name: "secrethidden") }

      before { create_hidden_tags(%w[secrethidden]) }

      let(:params) { { q: "secrethidden" } }

      it { is_expected.to run_successfully }

      it "does not expose the hidden tag as forbidden" do
        expect(result[:forbidden]).to be_nil
      end

      it "does not include the hidden tag in results" do
        expect(result[:tags].map { |t| t[:name] }).not_to include("secrethidden")
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

      it { is_expected.to run_successfully }

      it "propagates the required_tag_group from the filter context" do
        expect(result[:required_tag_group]).to be_present
        expect(result[:required_tag_group][:name]).to eq("Required Group")
        expect(result[:required_tag_group][:min_count]).to eq(1)
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
          expect(result[:tags].map { |t| t[:name] }).to contain_exactly("戦略")
        end
      end

      it "does not match localizations from other locales" do
        I18n.with_locale(:en) { expect(result[:tags].map { |t| t[:name] }).to be_empty }
      end
    end
  end
end
