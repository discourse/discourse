# frozen_string_literal: true

RSpec.describe PostItemExcerpt do
  fab!(:regular_post) { Fabricate(:post, raw: "abc " * 100) }
  fab!(:complex_post) { Fabricate(:post, raw: "<div>" * 10 + "Hello" + "</div>" * 10) }
  let!(:max_excerpt_length) { 300 + "&hellip;".size }

  class ExcerptSerializer < PostSerializer
    include PostItemExcerpt
  end

  context "with regular post structure" do
    it "includes excerpt and truncated attributes" do
      item = ExcerptSerializer.new(regular_post, scope: Guardian.new, root: false)

      expect(item.excerpt.size).to eq(max_excerpt_length)
      expect(item.truncated).to eq(true)
    end
  end

  context "with complex post structure" do
    it "works when HTML depth is within limits" do
      stub_const(Nokogiri::Gumbo, "DEFAULT_MAX_TREE_DEPTH", 20) do
        item = ExcerptSerializer.new(complex_post, scope: Guardian.new, root: false)
        expect(item.excerpt).to eq("Hello")
      end
    end

    it "returns nil when HTML depth exceeds limits" do
      stub_const(Nokogiri::Gumbo, "DEFAULT_MAX_TREE_DEPTH", 5) do
        item = ExcerptSerializer.new(complex_post, scope: Guardian.new, root: false)
        expect(item.excerpt).to eq(nil)
      end
    end
  end
end
