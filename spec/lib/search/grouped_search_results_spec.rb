# frozen_string_literal: true

describe Search::GroupedSearchResults do
  fab!(:posts) { Fabricate.times(3, :post) }

  def build_results(per_page: nil)
    described_class.new(
      type_filter: "topic",
      term: "hello",
      search_context: nil,
      per_page: per_page,
    )
  end

  describe "#add" do
    it "falls back to the site page size when `per_page` is omitted" do
      SiteSetting.search_page_size = 2
      results = build_results
      posts.each { |post| results.add(post) }

      expect(results.posts).to eq(posts.first(2))
      expect(results.more_full_page_results).to eq(true)
    end

    it "collects up to `per_page` posts and flags that more results exist" do
      results = build_results(per_page: 2)
      posts.each { |post| results.add(post) }

      expect(results.posts).to eq(posts.first(2))
      expect(results.more_full_page_results).to eq(true)
    end

    it "ignores a `per_page` above the site page size" do
      SiteSetting.search_page_size = 1
      results = build_results(per_page: 10)
      posts.each { |post| results.add(post) }

      expect(results.posts).to eq(posts.first(1))
      expect(results.more_full_page_results).to eq(true)
    end
  end
end
