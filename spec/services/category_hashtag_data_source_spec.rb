# frozen_string_literal: true

RSpec.describe CategoryHashtagDataSource do
  fab!(:parent_category) { Fabricate(:category, name: "Silly Land", slug: "fun", topic_count: 2) }
  fab!(:category1) do
    Fabricate(
      :category,
      name: "Random",
      slug: "random",
      topic_count: 12,
      parent_category: parent_category,
    )
  end
  fab!(:category2) { Fabricate(:category, name: "Book Section", slug: "books", topic_count: 566) }
  fab!(:category3) { Fabricate(:category, name: "Kino Korner", slug: "movies", topic_count: 245) }
  fab!(:group)
  fab!(:category4) do
    Fabricate(:private_category, name: "Nunya", slug: "secret", group: group, topic_count: 40)
  end
  fab!(:category5) { Fabricate(:category, name: "Chillzone", slug: "casual", topic_count: 99) }
  fab!(:user)
  let(:guardian) { Guardian.new(user) }
  let(:uncategorized_category) { Category.find(SiteSetting.uncategorized_category_id) }

  describe "#find_by_ids" do
    it "finds categories by their IDs" do
      expect(
        described_class.find_by_ids(guardian, [parent_category.id, category1.id]).map(&:slug),
      ).to contain_exactly("fun", "random")
    end

    it "does not find categories the user cannot access" do
      expect(described_class.find_by_ids(guardian, [category4.id]).first).to eq(nil)
      group.add(user)
      expect(described_class.find_by_ids(Guardian.new(user), [category4.id]).first).not_to eq(nil)
    end
  end

  describe "#lookup" do
    it "finds categories using their slug, downcasing for matches" do
      result = described_class.lookup(guardian, ["movies"]).first
      expect(result.ref).to eq("movies")
      expect(result.slug).to eq("movies")

      result = described_class.lookup(guardian, ["BoOKs"]).first
      expect(result.ref).to eq("books")
      expect(result.slug).to eq("books")
    end

    it "finds categories using the parent:child slug format" do
      result = described_class.lookup(guardian, ["fun:random"]).first
      expect(result.ref).to eq("fun:random")
      expect(result.slug).to eq("random")
    end

    it "does not find child categories by their standalone slug" do
      expect(described_class.lookup(guardian, ["random"]).first).to eq(nil)
    end

    it "does not find categories the user cannot access" do
      expect(described_class.lookup(guardian, ["secret"]).first).to eq(nil)
      group.add(user)
      expect(described_class.lookup(Guardian.new(user), ["secret"]).first).not_to eq(nil)
    end

    it "formats the category text for a category without a parent" do
      result = described_class.lookup(guardian, ["movies"]).first
      expect(result.text).to eq("Kino Korner")
    end

    it "formats the category text for a category with a parent" do
      result = described_class.lookup(guardian, ["fun:random"]).first
      expect(result.text).to eq("Silly Land > Random")
    end

    context "with sub-sub-categories" do
      before { SiteSetting.max_category_nesting = 3 }

      it "returns the first matching grandchild category (ordered by IDs) when there are multiple categories with the same slug" do
        parent1 = Fabricate(:category, slug: "parent1")
        parent2 = Fabricate(:category, slug: "parent2")

        parent1_child = Fabricate(:category, slug: "child", parent_category_id: parent1.id)
        parent1_child_grandchild =
          Fabricate(:category, slug: "grandchild", parent_category_id: parent1_child.id)

        parent2_child = Fabricate(:category, slug: "child", parent_category_id: parent2.id)
        parent2_child_grandchild =
          Fabricate(:category, slug: "grandchild", parent_category_id: parent2_child.id)

        result = described_class.lookup(guardian, ["child:grandchild"])
        expect(result.map(&:relative_url)).to eq([parent1_child_grandchild.url])

        parent1_child.destroy
        parent1_child = Fabricate(:category, slug: "child", parent_category_id: parent1.id)

        result = described_class.lookup(guardian, ["child:grandchild"])
        expect(result.map(&:relative_url)).to eq([parent2_child_grandchild.url])
      end

      it "returns the correct grandchild category when there are multiple children with the same slug and only one of them has the correct grandchild" do
        parent1 = Fabricate(:category, slug: "parent1")
        parent1_child = Fabricate(:category, slug: "child", parent_category_id: parent1.id)
        parent1_child_grandchild =
          Fabricate(:category, slug: "another-grandchild", parent_category_id: parent1_child.id)

        parent2 = Fabricate(:category, slug: "parent2")
        parent2_child = Fabricate(:category, slug: "child", parent_category_id: parent2.id)
        parent2_child_grandchild =
          Fabricate(:category, slug: "grandchild", parent_category_id: parent2_child.id)

        result = described_class.lookup(guardian, ["child:grandchild"])
        expect(result.map(&:relative_url)).to eq([parent2_child_grandchild.url])
      end

      it "formats the category text for sub-sub-categories" do
        parent = Fabricate(:category, slug: "parent", name: "Parent")
        child = Fabricate(:category, slug: "child", parent_category_id: parent.id, name: "Child")
        grandchild =
          Fabricate(:category, slug: "grandchild", parent_category_id: child.id, name: "Grandchild")
        result = described_class.lookup(guardian, ["child:grandchild"])
        expect(result.last.text).to eq("Child > Grandchild")
      end
    end
  end

  describe "#search" do
    it "finds categories by partial name" do
      result = described_class.search(guardian, "mov", 5).first
      expect(result.ref).to eq("movies")
      expect(result.slug).to eq("movies")
      expect(result.text).to eq("Kino Korner")
    end

    it "finds categories by partial slug" do
      result = described_class.search(guardian, "ook sec", 5).first
      expect(result.ref).to eq("books")
      expect(result.slug).to eq("books")
    end

    it "does not find categories the user cannot access" do
      expect(described_class.search(guardian, "secret", 5).first).to eq(nil)
      group.add(user)
      expect(described_class.search(Guardian.new(user), "secret", 5).first).not_to eq(nil)
    end

    it "uses the correct ref format for a parent:child category that is found" do
      result = described_class.search(guardian, "random", 5).first
      expect(result.ref).to eq("fun:random")
      expect(result.slug).to eq("random")
    end

    it "formats the text correctly for a parent:child category that is found" do
      result = described_class.search(guardian, "random", 5).first
      expect(result.text).to eq("Silly Land > Random")
    end
  end

  describe "#search_without_term" do
    it "returns distinct categories ordered by topic_count" do
      expect(described_class.search_without_term(guardian, 5).map(&:slug)).to eq(
        %w[books movies casual random fun],
      )
    end

    it "does not return categories the user does not have permission to view" do
      expect(described_class.search_without_term(guardian, 5).map(&:slug)).not_to include("secret")
      group.add(user)
      expect(described_class.search_without_term(Guardian.new(user), 5).map(&:slug)).to include(
        "secret",
      )
    end

    it "does not return categories the user has muted" do
      CategoryUser.create!(
        user: user,
        category: category1,
        notification_level: CategoryUser.notification_levels[:muted],
      )
      expect(described_class.search_without_term(guardian, 5).map(&:slug)).not_to include("random")
    end

    it "does not return child categories where the user has muted the parent" do
      CategoryUser.create!(
        user: user,
        category: parent_category,
        notification_level: CategoryUser.notification_levels[:muted],
      )
      expect(described_class.search_without_term(guardian, 5).map(&:slug)).not_to include("random")
    end
  end

  describe "#search_sort" do
    it "orders by exact slug match then text" do
      results_to_sort = [
        HashtagAutocompleteService::HashtagItem.new(
          text: "System Tests",
          slug: "system-test-development",
        ),
        HashtagAutocompleteService::HashtagItem.new(text: "Ruby Dev", slug: "ruby-dev"),
        HashtagAutocompleteService::HashtagItem.new(text: "Dev", slug: "dev"),
        HashtagAutocompleteService::HashtagItem.new(text: "Dev Tools", slug: "dev-tools"),
        HashtagAutocompleteService::HashtagItem.new(text: "Dev Lore", slug: "dev-lore"),
      ]
      expect(described_class.search_sort(results_to_sort, "dev").map(&:slug)).to eq(
        %w[dev dev-lore dev-tools ruby-dev system-test-development],
      )
    end
  end
end
