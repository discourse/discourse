# frozen_string_literal: true

RSpec.describe CategoryHashtagDataSource do
  fab!(:category1) { Fabricate(:category, slug: "random") }
  fab!(:category2) { Fabricate(:category, slug: "books") }
  fab!(:category3) { Fabricate(:category, slug: "movies") }
  fab!(:group) { Fabricate(:group) }
  fab!(:category4) { Fabricate(:private_category, slug: "secret", group: group) }
  fab!(:category5) { Fabricate(:category, slug: "casual") }
  fab!(:user) { Fabricate(:user) }
  let(:guardian) { Guardian.new(user) }

  describe "#search_without_term" do
    fab!(:topic1) { Fabricate(:topic, category: category1) }
    fab!(:topic2) { Fabricate(:topic, category: category2) }
    fab!(:topic3) { Fabricate(:topic, category: category3) }
    fab!(:topic4) { Fabricate(:topic, category: category4) }
    fab!(:topic5) { Fabricate(:topic, category: category5) }
    fab!(:post1) { Fabricate(:post, topic: topic1, created_at: 1.day.ago) }
    fab!(:post2) { Fabricate(:post, topic: topic1, created_at: 6.hours.ago) }
    fab!(:post3) { Fabricate(:post, topic: topic2, created_at: 1.hour.ago) }
    fab!(:post4) { Fabricate(:post, topic: topic3, created_at: 3.days.ago) }
    fab!(:post5) { Fabricate(:post, topic: topic4, created_at: 1.week.ago) }
    fab!(:post6) { Fabricate(:post, topic: topic4, created_at: 2.minutes.ago) }
    fab!(:post7) { Fabricate(:post, topic: topic5, created_at: 3.weeks.ago) }

    it "returns distinct categories attached to topics with posts that have been recently created in the past 2 weeks" do
      expect(described_class.search_without_term(guardian, 5).map(&:slug)).to match_array(
        %w[random books movies],
      )
    end

    it "does not return recent categories for posts created > 2 weeks ago" do
      expect(described_class.search_without_term(guardian, 5).map(&:slug)).not_to include(
        "casual",
      )
    end

    it "does not return categories the user does not have permission to view" do
      expect(described_class.search_without_term(guardian, 5).map(&:slug)).not_to include("secret")
    end

    it "does not return categories where the post that would match is deleted" do
      post4.trash!
      expect(described_class.search_without_term(guardian, 5).map(&:slug)).not_to include("movies")
    end

    it "does not return categories for deleted topics" do
      topic1.trash!
      expect(described_class.search_without_term(guardian, 5).map(&:slug)).not_to include("random")
    end
  end
end
