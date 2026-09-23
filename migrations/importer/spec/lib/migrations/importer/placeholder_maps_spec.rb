# frozen_string_literal: true

RSpec.describe Migrations::Importer::PlaceholderMaps do
  subject(:maps) { described_class.new(intermediate_db, discourse_db) }

  include_context "with importer databases"

  let(:discourse_db) { instance_double(Migrations::Importer::DiscourseDB) }

  def stub_query(sql, rows)
    allow(discourse_db).to receive(:query_array).with(sql).and_return(rows)
  end

  def add_post_number(original_id, topic_original_id, post_number)
    intermediate_db.execute(
      "INSERT INTO mapped.post_numbers (original_id, topic_original_id, post_number) VALUES (?, ?, ?)",
      original_id,
      topic_original_id,
      post_number,
    )
  end

  describe "#user" do
    it "answers with the destination username and name" do
      stub_query("SELECT id, username, name FROM users", [[7, "alice", "Alice A."]])
      add_mapping(101, mapping_type::USERS, 7)

      expect(maps.user(101).dig(:username)).to eq("alice")
      expect(maps.user(101).dig(:name)).to eq("Alice A.")
      expect(maps.user(999)).to be_nil
    end

    it "ignores a mapping whose destination record is gone" do
      stub_query("SELECT id, username, name FROM users", [])
      add_mapping(101, mapping_type::USERS, 7)

      expect(maps.user(101)).to be_nil
    end
  end

  describe "#group_name" do
    it "answers with the destination group name" do
      stub_query("SELECT id, name FROM groups", [[3, "staff_renamed"]])
      add_mapping(55, mapping_type::GROUPS, 3)

      expect(maps.group_name(55)).to eq("staff_renamed")
    end
  end

  describe "tags" do
    it "answers with the destination tag id and name" do
      stub_query("SELECT id, name FROM tags", [[8, "support"]])
      add_mapping(70, mapping_type::TAGS, 8)

      expect(maps.tag_id(70)).to eq(8)
      expect(maps.tag_name(70)).to eq("support")
    end
  end

  describe "categories" do
    before do
      stub_query(
        "SELECT id, slug, parent_category_id FROM categories",
        [[1, "parent", nil], [2, "child", 1], [3, "grandchild", 2]],
      )
      add_mapping(10, mapping_type::CATEGORIES, 1)
      add_mapping(20, mapping_type::CATEGORIES, 2)
      add_mapping(30, mapping_type::CATEGORIES, 3)
    end

    it "answers with the destination category id" do
      expect(maps.category_id(20)).to eq(2)
      expect(maps.category_id(99)).to be_nil
    end

    it "builds the slug path from the destination categories" do
      expect(maps.category_slug_path(10)).to eq("parent")
      expect(maps.category_slug_path(20)).to eq("parent:child")
      expect(maps.category_slug_path(30)).to eq("parent:child:grandchild")
    end

    it "stops at a looping parent chain" do
      stub_query(
        "SELECT id, slug, parent_category_id FROM categories",
        [[1, "one", 2], [2, "two", 1]],
      )

      expect(maps.category_slug_path(10)).to eq("two:one")
    end
  end

  describe "#topic_id" do
    it "answers with the destination topic id" do
      add_mapping(500, mapping_type::TOPICS, 42)

      expect(maps.topic_id(500)).to eq(42)
      expect(maps.topic_id(501)).to be_nil
    end
  end

  describe "#post" do
    before do
      add_mapping(500, mapping_type::TOPICS, 42)
      add_post_number(1, 500, 3)
      add_post_number(2, 500, 4)
      add_post_number(3, 501, 1)
    end

    it "answers with the destination topic id and post number" do
      maps.prime_posts([1])

      expect(maps.post(1).dig(:topic_id)).to eq(42)
      expect(maps.post(1).dig(:post_number)).to eq(3)
    end

    it "answers for a post outside the primed batch" do
      maps.prime_posts([1])

      expect(maps.post(2).dig(:post_number)).to eq(4)
    end

    it "answers with nil when the post's topic was not imported" do
      maps.prime_posts([3])

      expect(maps.post(3)).to be_nil
    end

    it "keeps only the posts of the last primed batch" do
      maps.prime_posts([1])
      maps.prime_posts([2])
      intermediate_db.execute("DELETE FROM mapped.post_numbers WHERE original_id = 1")

      expect(maps.post(1)).to be_nil
    end
  end

  describe "#emoji_name" do
    it "answers with the source spelling, looked up folded" do
      Migrations::Database::IntermediateDB::CustomEmoji.create(
        original_id: 1,
        name: "MyEmoji",
        upload_id: "u1",
      )

      expect(maps.emoji_name(Migrations::NameNormalizer.normalize("MYEMOJI"))).to eq("MyEmoji")
      expect(maps.emoji_name("unknown")).to be_nil
    end
  end

  describe "polls and events" do
    it "has no markdown for them yet" do
      expect(maps.poll_markdown(1)).to be_nil
      expect(maps.event_markdown(1)).to be_nil
    end
  end

  describe "#upload", :rails do
    it "derives the short URL from the stored attributes" do
      sha1 = "a" * 40
      add_upload_file(
        "u1",
        { sha1:, extension: "png", url: "//cdn.example.com/original/1X/abc.png" },
        markdown: "![pic](upload://abc.png)",
      )

      expect(maps.upload("u1").dig(:short_url)).to eq("upload://#{Upload.base62_sha1(sha1)}.png")
      expect(maps.upload("u1").dig(:url)).to eq("//cdn.example.com/original/1X/abc.png")
      expect(maps.upload_markdown("u1")).to eq("![pic](upload://abc.png)")
    end

    it "skips an upload that was never stored" do
      add_upload_file("u2", nil)

      expect(maps.upload("u2")).to be_nil
      expect(maps.upload_markdown("u2")).to be_nil
    end
  end

  describe "#badge", :rails do
    it "answers with the destination badge id and its slug" do
      stub_query("SELECT id, name FROM badges", [[9, "Great Share"]])
      add_mapping(90, mapping_type::BADGES, 9)

      expect(maps.badge(90).dig(:id)).to eq(9)
      expect(maps.badge(90).dig(:slug)).to eq("great-share")
    end
  end

  describe "destination site values", :rails do
    it "answers with the destination's own values" do
      expect(maps.base_url).to eq(Discourse.base_url)
      expect(maps.here_mention).to eq(SiteSetting.here_mention)
    end
  end
end
