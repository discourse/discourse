# frozen_string_literal: true

require "extralite"

RSpec.describe Migrations::Importer::Customizations::Matcher do
  let(:types) { Migrations::Importer::MappingType }
  let(:record) { Struct.new(:id).new(30) }

  let(:fake_strategy_class) do
    Struct.new(:name, :key, :ids) do
      def keys_for(_kind, record)
        { key => "#{name}-#{record.id}" }
      end

      def find_id(_kind, keys)
        ids[keys[key]]
      end
    end
  end

  around do |example|
    Dir.mktmpdir do |dir|
      @path = File.join(dir, "mappings.db")
      db = Extralite::Database.new(@path)
      db.execute(<<~SQL)
        CREATE TABLE ids (
          original_id NUMERIC NOT NULL,
          type INTEGER NOT NULL,
          discourse_id NUMERIC NOT NULL,
          PRIMARY KEY (original_id, type)
        )
      SQL
      db.execute(
        "INSERT INTO ids VALUES (7, ?, 30), (8, ?, 31), ('abc', ?, 40), (11, ?, 30), (12, ?, 30), ('t-1', ?, 30)",
        types::CATEGORIES,
        types::GROUPS,
        types::GROUPS,
        types::TOPICS,
        types::USERS,
        types::TAGS,
      )
      db.close
      example.run
    end
  end

  let(:mappings) do
    Migrations::Importer::Customizations::Matcher::Strategies::Mappings.new(
      Migrations::Importer::Customizations::MappingsDB.new(@path),
    )
  end

  after { mappings.close }

  describe "MappingsDB strategy" do
    it "maps discourse ids to original ids and back, per type" do
      expect(mappings.keys_for(:category, record)).to eq("original_id" => 7)
      expect(mappings.keys_for(:group, record)).to eq("original_id" => nil)

      expect(mappings.find_id(:category, "original_id" => 7)).to eq(30)
      expect(mappings.find_id(:category, "original_id" => "7")).to eq(30)
      expect(mappings.find_id(:group, "original_id" => "abc")).to eq(40)
      expect(mappings.find_id(:group, "original_id" => 7)).to be_nil
      expect(mappings.find_id(:group, {})).to be_nil
    end

    it "maps topics, users and tags, but has no mapping type for posts" do
      expect(mappings.keys_for(:topic, record)).to eq("original_id" => 11)
      expect(mappings.keys_for(:user, record)).to eq("original_id" => 12)
      expect(mappings.keys_for(:tag, record)).to eq("original_id" => "t-1")
      expect(mappings.keys_for(:post, record)).to eq({})

      expect(mappings.find_id(:topic, "original_id" => "11")).to eq(30)
      expect(mappings.find_id(:user, "original_id" => 12)).to eq(30)
      expect(mappings.find_id(:tag, "original_id" => "t-1")).to eq(30)
      expect(mappings.find_id(:post, "original_id" => 11)).to be_nil
    end

    it "opens the database read-only" do
      db = Migrations::Importer::Customizations::MappingsDB.new(@path)
      raw = db.instance_variable_get(:@db)
      expect { raw.execute("DELETE FROM ids") }.to raise_error(Extralite::Error)
      db.close
    end
  end

  it "collects the keys of all strategies" do
    natural = fake_strategy_class.new("natural_key", "slug_path", {})
    matcher = described_class.new([mappings, natural])

    expect(matcher.keys_for(:category, record)).to eq(
      "original_id" => 7,
      "slug_path" => "natural_key-30",
    )
  end

  it "resolves with the first strategy that finds an accepted id" do
    import_id = fake_strategy_class.new("import_id", "import_id", { "x" => 99 })
    natural = fake_strategy_class.new("natural_key", "slug_path", { "general" => 12 })
    matcher = described_class.new([mappings, import_id, natural])

    keys = { "original_id" => 7, "import_id" => "x", "slug_path" => "general" }

    expect(matcher.resolve(:category, keys).to_h).to eq(id: 30, strategy: "mappings_db")
    expect(matcher.resolve(:category, keys) { |id| id != 30 }.to_h).to eq(
      id: 99,
      strategy: "import_id",
    )
    expect(matcher.resolve(:category, keys) { |id| id == 12 }.to_h).to eq(
      id: 12,
      strategy: "natural_key",
    )
    expect(matcher.resolve(:category, { "slug_path" => "nope" })).to be_nil
  end
end
