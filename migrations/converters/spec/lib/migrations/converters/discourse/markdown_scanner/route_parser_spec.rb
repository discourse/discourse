# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::MarkdownScanner::Constructs::InternalLink::RouteParser do
  describe ".parse" do
    shared_examples "a numeric tag route" do |path:, suffix:|
      it "reads the numeric tag id from #{path}" do
        target = described_class.parse(path)

        expect(target).to include(target_type: :tag, target_id: 42, target_name: nil)
        expect(path[target[:route_length]..]).to eq(suffix)
      end
    end

    it_behaves_like "a numeric tag route", path: "/tag/release/42", suffix: ""
    it_behaves_like "a numeric tag route", path: "/tag/c/42", suffix: ""
    it_behaves_like "a numeric tag route", path: "/tag/intersection/42", suffix: ""
    it_behaves_like "a numeric tag route", path: "/tags/release/42/", suffix: "/"
    it_behaves_like "a numeric tag route",
                    path: "/tag/2015/42/l/latest?ascending=true#top",
                    suffix: "/l/latest?ascending=true#top"
    it_behaves_like "a numeric tag route",
                    path: "/tag/42.json?include=details",
                    suffix: ".json?include=details"
    it_behaves_like "a numeric tag route", path: "/tag/release/42.rss", suffix: ".rss"

    shared_examples "a numeric category route" do |path:, suffix:|
      it "reads the final category id from #{path}" do
        target = described_class.parse(path)

        expect(target).to include(target_type: :category, target_id: 456, target_name: nil)
        expect(path[target[:route_length]..]).to eq(suffix)
      end
    end

    it_behaves_like "a numeric category route", path: "/c/parent/123/456", suffix: ""
    it_behaves_like "a numeric category route", path: "/category/parent/123/456/", suffix: "/"
    it_behaves_like "a numeric category route", path: "/c/123/456", suffix: ""
    it_behaves_like "a numeric category route",
                    path: "/c/parent/123/456/l/top/weekly?ascending=true#top",
                    suffix: "/l/top/weekly?ascending=true#top"
    it_behaves_like "a numeric category route",
                    path: "/c/parent/123/456/none/bug/12",
                    suffix: "/none/bug/12"
    it_behaves_like "a numeric category route", path: "/c/parent/123/456/all", suffix: "/all"
    it_behaves_like "a numeric category route",
                    path: "/c/parent/123/456/subcategories",
                    suffix: "/subcategories"
    it_behaves_like "a numeric category route", path: "/c/parent/123/456.json", suffix: ".json"

    it "keeps reserved multi-tag routes out of single-tag id parsing" do
      expect(described_class.parse("/tags/c/support/feature/12")).to be_nil
      expect(described_class.parse("/tags/intersection/release/42")).to include(
        target_type: :tag_intersection,
        target_tag_path: "release/42",
      )
    end

    it "keeps numeric segments in an id-less category slug path" do
      expect(described_class.parse("/c/parent/123/child/l/latest")).to include(
        target_type: :category,
        target_id: nil,
        target_name: "parent:123:child",
      )
    end
  end
end
