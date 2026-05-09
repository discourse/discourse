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

      it "includes the one_per_topic reason" do
        disabled = result[:tags].find { |t| t[:name] == "gamma" && t[:disabled] }
        expect(disabled[:title]).to include("Exclusive Group")
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
