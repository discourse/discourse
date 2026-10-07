# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::MarkdownScanner::Constructs::InternalLink::RouteParser do
  describe ".parse" do
    {
      "/tag/release/42" => "",
      "/tag/c/42" => "",
      "/tag/intersection/42" => "",
      "/tags/release/42/" => "/",
      "/tag/2015/42/l/latest?ascending=true#top" => "/l/latest?ascending=true#top",
      "/tag/42.json?include=details" => ".json?include=details",
      "/tag/release/42.rss" => ".rss",
    }.each do |path, suffix|
      it "reads the numeric tag id from #{path}" do
        target = described_class.parse(path)

        expect(target).to include(target_type: :tag, target_id: 42, target_name: nil)
        expect(path[target[:route_length]..]).to eq(suffix)
      end
    end

    {
      "/c/parent/123/456" => "",
      "/category/parent/123/456/" => "/",
      "/c/123/456" => "",
      "/c/parent/123/456/l/top/weekly?ascending=true#top" => "/l/top/weekly?ascending=true#top",
      "/c/parent/123/456/none/bug/12" => "/none/bug/12",
      "/c/parent/123/456/all" => "/all",
      "/c/parent/123/456/subcategories" => "/subcategories",
      "/c/parent/123/456.json" => ".json",
    }.each do |path, suffix|
      it "reads the final category id from #{path}" do
        target = described_class.parse(path)

        expect(target).to include(target_type: :category, target_id: 456, target_name: nil)
        expect(path[target[:route_length]..]).to eq(suffix)
      end
    end

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
