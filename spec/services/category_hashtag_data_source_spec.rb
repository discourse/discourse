# frozen_string_literal: true

RSpec.describe CategoryHashtagDataSource do
  fab!(:category1) { Fabricate(:category, slug: "random", topic_count: 432) }
  fab!(:category2) { Fabricate(:category, slug: "books", topic_count: 235) }
  fab!(:category3) { Fabricate(:category, slug: "movies", topic_count: 126) }
  fab!(:group) { Fabricate(:group) }
  fab!(:category4) { Fabricate(:private_category, slug: "secret", group: group, topic_count: 40) }
  fab!(:category5) { Fabricate(:category, slug: "casual", topic_count: 99) }
  fab!(:user) { Fabricate(:user) }
  let(:guardian) { Guardian.new(user) }
  let(:uncategorized_category) { Category.find(SiteSetting.uncategorized_category_id) }

  describe "#search_without_term" do
    it "returns distinct categories ordered by topic_count" do
      expect(described_class.search_without_term(guardian, 5).map(&:slug)).to eq(
        ["random", "books", "movies", "casual", "#{uncategorized_category.slug}"],
      )
    end

    it "does not return categories the user does not have permission to view" do
      expect(described_class.search_without_term(guardian, 5).map(&:slug)).not_to include("secret")
      GroupUser.create(user: user, group: group)
      expect(described_class.search_without_term(guardian, 5).map(&:slug)).to include("secret")
    end

    it "does not return categories the user has muted" do
      CategoryUser.create(
        user: user,
        category: category1,
        notification_level: CategoryUser.notification_levels[:muted],
      )
      expect(described_class.search_without_term(guardian, 5).map(&:slug)).not_to include("random")
    end
  end
end
