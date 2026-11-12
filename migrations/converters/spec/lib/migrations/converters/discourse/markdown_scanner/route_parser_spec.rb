# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::MarkdownScanner::Constructs::InternalLink::RouteParser do
  describe ".parse" do
    shared_examples "reading a numeric tag route" do |path:, expected_suffix:|
      it "reads the target ID and preserves the route suffix" do
        target = described_class.parse(path)

        expect(target).to include(target_type: :tag, target_id: 42, target_name: nil)
        expect(path[target[:route_length]..]).to eq(expected_suffix)
      end
    end

    context "with a tag slug before its ID" do
      include_examples "reading a numeric tag route", path: "/tag/release/42", expected_suffix: ""
    end

    context "with c as the tag slug" do
      include_examples "reading a numeric tag route", path: "/tag/c/42", expected_suffix: ""
    end

    context "with intersection as the tag slug" do
      include_examples "reading a numeric tag route",
                       path: "/tag/intersection/42",
                       expected_suffix: ""
    end

    context "with the tags alias and a trailing slash" do
      include_examples "reading a numeric tag route",
                       path: "/tags/release/42/",
                       expected_suffix: "/"
    end

    context "with a numeric tag slug and a list suffix" do
      include_examples "reading a numeric tag route",
                       path: "/tag/2015/42/l/latest?ascending=true#top",
                       expected_suffix: "/l/latest?ascending=true#top"
    end

    context "with a JSON tag request and query string" do
      include_examples "reading a numeric tag route",
                       path: "/tag/42.json?include=details",
                       expected_suffix: ".json?include=details"
    end

    context "with an RSS tag request" do
      include_examples "reading a numeric tag route",
                       path: "/tag/release/42.rss",
                       expected_suffix: ".rss"
    end

    shared_examples "reading a numeric category route" do |path:, expected_suffix:|
      it "reads the target ID and preserves the route suffix" do
        target = described_class.parse(path)

        expect(target).to include(target_type: :category, target_id: 456, target_name: nil)
        expect(path[target[:route_length]..]).to eq(expected_suffix)
      end
    end

    context "with parent and child category IDs" do
      include_examples "reading a numeric category route",
                       path: "/c/parent/123/456",
                       expected_suffix: ""
    end

    context "with the category alias and a trailing slash" do
      include_examples "reading a numeric category route",
                       path: "/category/parent/123/456/",
                       expected_suffix: "/"
    end

    context "with only numeric category segments" do
      include_examples "reading a numeric category route", path: "/c/123/456", expected_suffix: ""
    end

    context "with a top period and query string" do
      include_examples "reading a numeric category route",
                       path: "/c/parent/123/456/l/top/weekly?ascending=true#top",
                       expected_suffix: "/l/top/weekly?ascending=true#top"
    end

    context "with a none filter and tag suffix" do
      include_examples "reading a numeric category route",
                       path: "/c/parent/123/456/none/bug/12",
                       expected_suffix: "/none/bug/12"
    end

    context "with the all filter" do
      include_examples "reading a numeric category route",
                       path: "/c/parent/123/456/all",
                       expected_suffix: "/all"
    end

    context "with the subcategories filter" do
      include_examples "reading a numeric category route",
                       path: "/c/parent/123/456/subcategories",
                       expected_suffix: "/subcategories"
    end

    context "with a JSON category request" do
      include_examples "reading a numeric category route",
                       path: "/c/parent/123/456.json",
                       expected_suffix: ".json"
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
