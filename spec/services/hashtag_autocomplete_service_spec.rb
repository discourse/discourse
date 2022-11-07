# frozen_string_literal: true

RSpec.describe HashtagAutocompleteService do
  fab!(:user) { Fabricate(:user) }
  fab!(:category1) { Fabricate(:category, name: "Book Club", slug: "book-club") }
  fab!(:tag1) { Fabricate(:tag, name: "great-books") }
  let(:guardian) { Guardian.new(user) }

  subject { described_class.new(guardian) }

  before { Site.clear_cache }

  def register_bookmark_data_source
    HashtagAutocompleteService.register_data_source("bookmark") do |guardian_scoped, term, limit|
      guardian_scoped
        .user
        .bookmarks
        .where("name ILIKE ?", "%#{term}%")
        .limit(limit)
        .map do |bm|
          HashtagAutocompleteService::HashtagItem.new.tap do |item|
            item.text = bm.name
            item.slug = bm.name.gsub(" ", "-")
            item.icon = "bookmark"
          end
        end
    end
  end

  describe "#search" do
    it "returns search results for tags and categories by default" do
      expect(subject.search("book", %w[category tag]).map(&:text)).to eq(
        ["Book Club", "great-books x 0"],
      )
    end

    it "respects the types_in_priority_order param" do
      expect(subject.search("book", %w[tag category]).map(&:text)).to eq(
        ["great-books x 0", "Book Club"],
      )
    end

    it "respects the limit param" do
      expect(subject.search("book", %w[tag category], limit: 1).map(&:text)).to eq(["great-books x 0"])
    end

    it "does not allow more than SEARCH_MAX_LIMIT results to be specified by the limit param" do
      stub_const(HashtagAutocompleteService, "SEARCH_MAX_LIMIT", 1) do
        expect(subject.search("book", %w[category tag], limit: 1000).map(&:text)).to eq(
          ["Book Club"],
        )
      end
    end

    it "does not search other data sources if the limit is reached by earlier type data sources" do
      Site.any_instance.expects(:categories).never
      subject.search("book", %w[tag category], limit: 1)
    end

    it "includes the tag count" do
      tag1.update!(topic_count: 78)
      expect(subject.search("book", %w[tag category]).map(&:text)).to eq(["great-books x 78", "Book Club"])
    end

    it "does case-insensitive search" do
      expect(subject.search("book", %w[category tag]).map(&:text)).to eq(
        ["Book Club", "great-books x 0"],
      )
      expect(subject.search("bOOk", %w[category tag]).map(&:text)).to eq(
        ["Book Club", "great-books x 0"],
      )
    end

    it "does not include categories the user cannot access" do
      category1.update!(read_restricted: true)
      expect(subject.search("book", %w[tag category]).map(&:text)).to eq(["great-books x 0"])
    end

    it "does not include tags the user cannot access" do
      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: ["great-books"])
      expect(subject.search("book", %w[tag]).map(&:text)).to be_empty
    end

    it "includes other data sources" do
      Fabricate(:bookmark, user: user, name: "read review of this fantasy book")
      Fabricate(:bookmark, user: user, name: "cool rock song")
      guardian.user.reload

      HashtagAutocompleteService.register_data_source("bookmark") do |guardian_scoped, term, limit|
        guardian_scoped
          .user
          .bookmarks
          .where("name ILIKE ?", "%#{term}%")
          .limit(limit)
          .map do |bm|
            HashtagAutocompleteService::HashtagItem.new.tap do |item|
              item.text = bm.name
              item.slug = bm.name.dasherize
              item.icon = "bookmark"
            end
          end
      end

      expect(subject.search("book", %w[category tag bookmark]).map(&:text)).to eq(
        ["Book Club", "great-books x 0", "read review of this fantasy book"],
      )
    end

    it "handles refs for categories that have a parent" do
      parent = Fabricate(:category, name: "Hobbies", slug: "hobbies")
      category1.update!(parent_category: parent)
      expect(subject.search("book", %w[category tag]).map(&:ref)).to eq(
        %w[hobbies:book-club great-books],
      )
    end

    it "appends type suffixes for the ref on conflicting slugs on items that are not the top priority type" do
      Fabricate(:tag, name: "book-club")
      expect(subject.search("book", %w[category tag]).map(&:ref)).to eq(
        %w[book-club book-club::tag great-books],
      )

      Fabricate(:bookmark, user: user, name: "book club")
      guardian.user.reload

      register_bookmark_data_source

      expect(subject.search("book", %w[category tag bookmark]).map(&:ref)).to eq(
        %w[book-club book-club::tag great-books book-club::bookmark],
      )
    end

    context "when multiple tags and categories are returned" do
      fab!(:category2) { Fabricate(:category, name: "Book Zone", slug: "book-zone") }
      fab!(:category3) { Fabricate(:category, name: "Book Dome", slug: "book-dome") }
      fab!(:tag2) { Fabricate(:tag, name: "mid-books") }
      fab!(:tag3) { Fabricate(:tag, name: "terrible-books") }

      it "orders them by name within their type order" do
        expect(subject.search("book", %w[category tag], limit: 10).map(&:ref)).to eq(
          %w[book-club book-dome book-zone great-books mid-books terrible-books],
        )
      end
    end

    context "when not tagging_enabled" do
      before { SiteSetting.tagging_enabled = false }

      it "does not return any tags" do
        expect(subject.search("book", %w[category tag]).map(&:text)).to eq(["Book Club"])
      end
    end
  end
end
