# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::MarkdownScanner::Constructs::InternalLink::RouteParser do
  describe ".parse" do
    it "reads the numeric tag id from /tag/release/42" do
      target = described_class.parse("/tag/release/42")

      expect(target).to include(target_type: :tag, target_id: 42, target_name: nil)
      expect("/tag/release/42"[target[:route_length]..]).to eq("")
    end

    it "reads the numeric tag id from /tag/c/42" do
      target = described_class.parse("/tag/c/42")

      expect(target).to include(target_type: :tag, target_id: 42, target_name: nil)
      expect("/tag/c/42"[target[:route_length]..]).to eq("")
    end

    it "reads the numeric tag id from /tag/intersection/42" do
      target = described_class.parse("/tag/intersection/42")

      expect(target).to include(target_type: :tag, target_id: 42, target_name: nil)
      expect("/tag/intersection/42"[target[:route_length]..]).to eq("")
    end

    it "reads the numeric tag id from /tags/release/42/" do
      target = described_class.parse("/tags/release/42/")

      expect(target).to include(target_type: :tag, target_id: 42, target_name: nil)
      expect("/tags/release/42/"[target[:route_length]..]).to eq("/")
    end

    it "reads the numeric tag id from /tag/2015/42/l/latest?ascending=true#top" do
      target = described_class.parse("/tag/2015/42/l/latest?ascending=true#top")

      expect(target).to include(target_type: :tag, target_id: 42, target_name: nil)
      expect("/tag/2015/42/l/latest?ascending=true#top"[target[:route_length]..]).to eq(
        "/l/latest?ascending=true#top",
      )
    end

    it "reads the numeric tag id from /tag/42.json?include=details" do
      target = described_class.parse("/tag/42.json?include=details")

      expect(target).to include(target_type: :tag, target_id: 42, target_name: nil)
      expect("/tag/42.json?include=details"[target[:route_length]..]).to eq(".json?include=details")
    end

    it "reads the numeric tag id from /tag/release/42.rss" do
      target = described_class.parse("/tag/release/42.rss")

      expect(target).to include(target_type: :tag, target_id: 42, target_name: nil)
      expect("/tag/release/42.rss"[target[:route_length]..]).to eq(".rss")
    end

    it "reads the final category id from /c/parent/123/456" do
      target = described_class.parse("/c/parent/123/456")

      expect(target).to include(target_type: :category, target_id: 456, target_name: nil)
      expect("/c/parent/123/456"[target[:route_length]..]).to eq("")
    end

    it "reads the final category id from /category/parent/123/456/" do
      target = described_class.parse("/category/parent/123/456/")

      expect(target).to include(target_type: :category, target_id: 456, target_name: nil)
      expect("/category/parent/123/456/"[target[:route_length]..]).to eq("/")
    end

    it "reads the final category id from /c/123/456" do
      target = described_class.parse("/c/123/456")

      expect(target).to include(target_type: :category, target_id: 456, target_name: nil)
      expect("/c/123/456"[target[:route_length]..]).to eq("")
    end

    it "reads the final category id from /c/parent/123/456/l/top/weekly?ascending=true#top" do
      target = described_class.parse("/c/parent/123/456/l/top/weekly?ascending=true#top")

      expect(target).to include(target_type: :category, target_id: 456, target_name: nil)
      expect("/c/parent/123/456/l/top/weekly?ascending=true#top"[target[:route_length]..]).to eq(
        "/l/top/weekly?ascending=true#top",
      )
    end

    it "reads the final category id from /c/parent/123/456/none/bug/12" do
      target = described_class.parse("/c/parent/123/456/none/bug/12")

      expect(target).to include(target_type: :category, target_id: 456, target_name: nil)
      expect("/c/parent/123/456/none/bug/12"[target[:route_length]..]).to eq("/none/bug/12")
    end

    it "reads the final category id from /c/parent/123/456/all" do
      target = described_class.parse("/c/parent/123/456/all")

      expect(target).to include(target_type: :category, target_id: 456, target_name: nil)
      expect("/c/parent/123/456/all"[target[:route_length]..]).to eq("/all")
    end

    it "reads the final category id from /c/parent/123/456/subcategories" do
      target = described_class.parse("/c/parent/123/456/subcategories")

      expect(target).to include(target_type: :category, target_id: 456, target_name: nil)
      expect("/c/parent/123/456/subcategories"[target[:route_length]..]).to eq("/subcategories")
    end

    it "reads the final category id from /c/parent/123/456.json" do
      target = described_class.parse("/c/parent/123/456.json")

      expect(target).to include(target_type: :category, target_id: 456, target_name: nil)
      expect("/c/parent/123/456.json"[target[:route_length]..]).to eq(".json")
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
