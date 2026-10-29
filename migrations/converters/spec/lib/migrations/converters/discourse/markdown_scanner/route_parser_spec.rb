# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::MarkdownScanner::Constructs::InternalLink::RouteParser do
  describe ".parse" do
    shared_examples "route parser for path and suffix" do |path, suffix|
      it "reads the numeric tag id from #{path}" do
        target = described_class.parse(path)

        expect(target).to include(target_type: :tag, target_id: 42, target_name: nil)
        expect(path[target[:route_length]..]).to eq(suffix)
      end
    end

    include_examples "route parser for path and suffix", ["/tag/release/42", ""]
    include_examples "route parser for path and suffix", ["/tag/c/42", ""]
    include_examples "route parser for path and suffix", ["/tag/intersection/42", ""]
    include_examples "route parser for path and suffix", %w[/tags/release/42/ /]
    include_examples "route parser for path and suffix",
                     %w[/tag/2015/42/l/latest?ascending=true#top /l/latest?ascending=true#top]
    include_examples "route parser for path and suffix",
                     %w[/tag/42.json?include=details .json?include=details]
    include_examples "route parser for path and suffix", %w[/tag/release/42.rss .rss]

    shared_examples "route parser for path and suffix (2)" do |path, suffix|
      it "reads the final category id from #{path}" do
        target = described_class.parse(path)

        expect(target).to include(target_type: :category, target_id: 456, target_name: nil)
        expect(path[target[:route_length]..]).to eq(suffix)
      end
    end

    include_examples "route parser for path and suffix (2)", ["/c/parent/123/456", ""]
    include_examples "route parser for path and suffix (2)", %w[/category/parent/123/456/ /]
    include_examples "route parser for path and suffix (2)", ["/c/123/456", ""]
    include_examples "route parser for path and suffix (2)",
                     %w[
                       /c/parent/123/456/l/top/weekly?ascending=true#top
                       /l/top/weekly?ascending=true#top
                     ]
    include_examples "route parser for path and suffix (2)",
                     %w[/c/parent/123/456/none/bug/12 /none/bug/12]
    include_examples "route parser for path and suffix (2)", %w[/c/parent/123/456/all /all]
    include_examples "route parser for path and suffix (2)",
                     %w[/c/parent/123/456/subcategories /subcategories]
    include_examples "route parser for path and suffix (2)", %w[/c/parent/123/456.json .json]

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
