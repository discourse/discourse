# frozen_string_literal: true

RSpec.describe HashtagAutocompleteService do
  fab!(:user) { Fabricate(:user) }
  fab!(:category1) { Fabricate(:category, name: "Book Club", slug: "book-club") }
  fab!(:tag1) { Fabricate(:tag, name: "great-books") }
  let(:guardian) { Guardian.new(user) }

  subject { described_class.new(guardian) }

  before { Site.clear_cache }

  class BookmarkDataSource
    def self.icon
      "bookmark"
    end

    def self.lookup(guardian_scoped, slugs)
      guardian_scoped
        .user
        .bookmarks
        .where("LOWER(name) IN (:slugs)", slugs: slugs)
        .map do |bm|
          HashtagAutocompleteService::HashtagItem.new.tap do |item|
            item.text = bm.name
            item.slug = bm.name.gsub(" ", "-")
            item.icon = icon
          end
        end
    end

    def self.search(guardian_scoped, term, limit)
      guardian_scoped
        .user
        .bookmarks
        .where("name ILIKE ?", "%#{term}%")
        .limit(limit)
        .map do |bm|
          HashtagAutocompleteService::HashtagItem.new.tap do |item|
            item.text = bm.name
            item.slug = bm.name.gsub(" ", "-")
            item.icon = icon
          end
        end
    end
  end

  describe ".contexts_with_ordered_types" do
    it "returns a hash of all the registrered search contexts and their types in the defined priority order" do
      expect(HashtagAutocompleteService.contexts_with_ordered_types).to eq(
        { "topic-composer" => %w[category tag] },
      )
      HashtagAutocompleteService.register_type_in_context("category", "awesome-composer", 50)
      HashtagAutocompleteService.register_type_in_context("tag", "awesome-composer", 100)
      expect(HashtagAutocompleteService.contexts_with_ordered_types).to eq(
        { "topic-composer" => %w[category tag], "awesome-composer" => %w[tag category] },
      )
    end
  end

  describe ".data_source_icons" do
    it "gets an array for all icons defined by data sources so they can be used for markdown allowlisting" do
      expect(HashtagAutocompleteService.data_source_icons).to eq(%w[folder tag])
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
      expect(subject.search("book", %w[tag category], limit: 1).map(&:text)).to eq(
        ["great-books x 0"],
      )
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
      expect(subject.search("book", %w[tag category]).map(&:text)).to eq(
        ["great-books x 78", "Book Club"],
      )
    end

    it "does case-insensitive search" do
      expect(subject.search("book", %w[category tag]).map(&:text)).to eq(
        ["Book Club", "great-books x 0"],
      )
      expect(subject.search("bOOk", %w[category tag]).map(&:text)).to eq(
        ["Book Club", "great-books x 0"],
      )
    end

    it "can search categories by name or slug" do
      expect(subject.search("book-club", %w[category]).map(&:text)).to eq(["Book Club"])
      expect(subject.search("Book C", %w[category]).map(&:text)).to eq(["Book Club"])
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

      HashtagAutocompleteService.register_data_source("bookmark", BookmarkDataSource)

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
      category1.update!(parent_category: nil)
    end

    it "appends type suffixes for the ref on conflicting slugs on items that are not the top priority type" do
      Fabricate(:tag, name: "book-club")
      expect(subject.search("book", %w[category tag]).map(&:ref)).to eq(
        %w[book-club book-club::tag great-books],
      )

      Fabricate(:bookmark, user: user, name: "book club")
      guardian.user.reload

      HashtagAutocompleteService.register_data_source("bookmark", BookmarkDataSource)

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

  describe "#lookup_old" do
    fab!(:tag2) { Fabricate(:tag, name: "fiction-books") }

    it "returns categories and tags in a hash format with the slug and url" do
      result = subject.lookup_old(%w[book-club great-books fiction-books])
      expect(result[:categories]).to eq({ "book-club" => "/c/book-club/#{category1.id}" })
      expect(result[:tags]).to eq(
        {
          "fiction-books" => "http://test.localhost/tag/fiction-books",
          "great-books" => "http://test.localhost/tag/great-books",
        },
      )
    end

    it "does not include categories the user cannot access" do
      category1.update!(read_restricted: true)
      result = subject.lookup_old(%w[book-club great-books fiction-books])
      expect(result[:categories]).to eq({})
    end

    it "does not include tags the user cannot access" do
      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: ["great-books"])
      result = subject.lookup_old(%w[book-club great-books fiction-books])
      expect(result[:tags]).to eq({ "fiction-books" => "http://test.localhost/tag/fiction-books" })
    end

    it "handles tags which have the ::tag suffix" do
      result = subject.lookup_old(%w[book-club great-books::tag fiction-books])
      expect(result[:tags]).to eq(
        {
          "fiction-books" => "http://test.localhost/tag/fiction-books",
          "great-books" => "http://test.localhost/tag/great-books",
        },
      )
    end

    context "when not tagging_enabled" do
      before { SiteSetting.tagging_enabled = false }

      it "does not return tags" do
        result = subject.lookup_old(%w[book-club great-books fiction-books])
        expect(result[:categories]).to eq({ "book-club" => "/c/book-club/#{category1.id}" })
        expect(result[:tags]).to eq({})
      end
    end
  end

  describe "#lookup" do
    fab!(:tag2) { Fabricate(:tag, name: "fiction-books") }

    it "returns category and tag in a hash format with the slug and url" do
      result = subject.lookup(%w[book-club great-books fiction-books], %w[category tag])
      expect(result[:category].map(&:slug)).to eq(["book-club"])
      expect(result[:category].map(&:relative_url)).to eq(["/c/book-club/#{category1.id}"])
      expect(result[:tag].map(&:slug)).to eq(%w[fiction-books great-books])
      expect(result[:tag].map(&:relative_url)).to eq(%w[/tag/fiction-books /tag/great-books])
    end

    it "does not include category the user cannot access" do
      category1.update!(read_restricted: true)
      result = subject.lookup(%w[book-club great-books fiction-books], %w[category tag])
      expect(result[:category]).to eq([])
    end

    it "does not include tag the user cannot access" do
      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: ["great-books"])
      result = subject.lookup(%w[book-club great-books fiction-books], %w[category tag])
      expect(result[:tag].map(&:slug)).to eq(%w[fiction-books])
      expect(result[:tag].map(&:relative_url)).to eq(["/tag/fiction-books"])
    end

    it "handles type suffixes for slugs" do
      result =
        subject.lookup(%w[book-club::category great-books::tag fiction-books], %w[category tag])
      expect(result[:category].map(&:slug)).to eq(["book-club"])
      expect(result[:category].map(&:relative_url)).to eq(["/c/book-club/#{category1.id}"])
      expect(result[:tag].map(&:slug)).to eq(%w[fiction-books great-books])
      expect(result[:tag].map(&:relative_url)).to eq(%w[/tag/fiction-books /tag/great-books])
    end

    it "handles parent:child category lookups" do
      parent_category = Fabricate(:category, name: "Media", slug: "media")
      category1.update!(parent_category: parent_category)
      result = subject.lookup(%w[media:book-club], %w[category tag])
      expect(result[:category].map(&:slug)).to eq(["book-club"])
      expect(result[:category].map(&:ref)).to eq(["media:book-club"])
      expect(result[:category].map(&:relative_url)).to eq(["/c/media/book-club/#{category1.id}"])
      category1.update!(parent_category: nil)
    end

    it "does not return the category if the parent does not match the child" do
      parent_category = Fabricate(:category, name: "Media", slug: "media")
      category1.update!(parent_category: parent_category)
      result = subject.lookup(%w[bad-parent:book-club], %w[category tag])
      expect(result[:category]).to be_empty
    end

    it "for slugs without a type suffix it falls back in type order until a result is found or types are exhausted" do
      result = subject.lookup(%w[book-club great-books fiction-books], %w[category tag])
      expect(result[:category].map(&:slug)).to eq(["book-club"])
      expect(result[:category].map(&:relative_url)).to eq(["/c/book-club/#{category1.id}"])
      expect(result[:tag].map(&:slug)).to eq(%w[fiction-books great-books])
      expect(result[:tag].map(&:relative_url)).to eq(%w[/tag/fiction-books /tag/great-books])

      category2 = Fabricate(:category, name: "Great Books", slug: "great-books")
      result = subject.lookup(%w[book-club great-books fiction-books], %w[category tag])
      expect(result[:category].map(&:slug)).to eq(%w[book-club great-books])
      expect(result[:category].map(&:relative_url)).to eq(
        ["/c/book-club/#{category1.id}", "/c/great-books/#{category2.id}"],
      )
      expect(result[:tag].map(&:slug)).to eq(%w[fiction-books])
      expect(result[:tag].map(&:relative_url)).to eq(%w[/tag/fiction-books])

      category1.destroy!
      Fabricate(:tag, name: "book-club")
      result = subject.lookup(%w[book-club great-books fiction-books], %w[category tag])
      expect(result[:category].map(&:slug)).to eq(["great-books"])
      expect(result[:category].map(&:relative_url)).to eq(["/c/great-books/#{category2.id}"])
      expect(result[:tag].map(&:slug)).to eq(%w[book-club fiction-books])
      expect(result[:tag].map(&:relative_url)).to eq(%w[/tag/book-club /tag/fiction-books])

      result = subject.lookup(%w[book-club great-books fiction-books], %w[tag category])
      expect(result[:category]).to eq([])
      expect(result[:tag].map(&:slug)).to eq(%w[book-club fiction-books great-books])
      expect(result[:tag].map(&:relative_url)).to eq(
        %w[/tag/book-club /tag/fiction-books /tag/great-books],
      )
    end

    it "includes other data sources" do
      Fabricate(:bookmark, user: user, name: "read review of this fantasy book")
      Fabricate(:bookmark, user: user, name: "coolrock")
      guardian.user.reload

      HashtagAutocompleteService.register_data_source("bookmark", BookmarkDataSource)

      result = subject.lookup(["coolrock"], %w[category tag bookmark])
      expect(result[:bookmark].map(&:slug)).to eq(["coolrock"])
    end

    context "when not tagging_enabled" do
      before { SiteSetting.tagging_enabled = false }

      it "does not return tag" do
        result = subject.lookup(%w[book-club great-books fiction-books], %w[category tag])
        expect(result[:category].map(&:slug)).to eq(["book-club"])
        expect(result[:category].map(&:relative_url)).to eq(["/c/book-club/#{category1.id}"])
        expect(result[:tag]).to eq([])
      end
    end
  end
end
