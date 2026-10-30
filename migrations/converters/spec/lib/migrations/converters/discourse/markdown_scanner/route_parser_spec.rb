# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::MarkdownScanner::Constructs::InternalLink::RouteParser do
  describe ".parse" do
    shared_examples "a numeric tag route" do |path, suffix|
      it "reads the numeric tag id from #{path}" do
        target = described_class.parse(path)

        expect(target).to include(target_type: :tag, target_id: 42, target_name: nil)
        expect(path[target[:route_length]..]).to eq(suffix)
      end
    end

    it_behaves_like "a numeric tag route", ["/tag/release/42", ""]
    it_behaves_like "a numeric tag route", ["/tag/c/42", ""]
    it_behaves_like "a numeric tag route", ["/tag/intersection/42", ""]
    it_behaves_like "a numeric tag route", %w[/tags/release/42/ /]
    it_behaves_like "a numeric tag route",
                    %w[/tag/2015/42/l/latest?ascending=true#top /l/latest?ascending=true#top]
    it_behaves_like "a numeric tag route", %w[/tag/42.json?include=details .json?include=details]
    it_behaves_like "a numeric tag route", %w[/tag/release/42.rss .rss]

    shared_examples "a numeric category route" do |path, suffix|
      it "reads the final category id from #{path}" do
        target = described_class.parse(path)

        expect(target).to include(target_type: :category, target_id: 456, target_name: nil)
        expect(path[target[:route_length]..]).to eq(suffix)
      end
    end

    it_behaves_like "a numeric category route", ["/c/parent/123/456", ""]
    it_behaves_like "a numeric category route", %w[/category/parent/123/456/ /]
    it_behaves_like "a numeric category route", ["/c/123/456", ""]
    it_behaves_like "a numeric category route",
                    %w[
                      /c/parent/123/456/l/top/weekly?ascending=true#top
                      /l/top/weekly?ascending=true#top
                    ]
    it_behaves_like "a numeric category route", %w[/c/parent/123/456/none/bug/12 /none/bug/12]
    it_behaves_like "a numeric category route", %w[/c/parent/123/456/all /all]
    it_behaves_like "a numeric category route", %w[/c/parent/123/456/subcategories /subcategories]
    it_behaves_like "a numeric category route", %w[/c/parent/123/456.json .json]

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
