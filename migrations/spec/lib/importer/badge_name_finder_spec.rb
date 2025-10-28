# frozen_string_literal: true

RSpec.describe Migrations::Importer::BadgeNameFinder do
  subject(:finder) { described_class.new(shared_data) }

  let(:discourse_db) { ::Migrations::Importer::DiscourseDB.new }
  let(:shared_data) { ::Migrations::Importer::SharedData.new(discourse_db) }

  let(:badges) do
    [
      { id: 1, name: "Basic Badge" },
      { id: 2, name: "Another Badge" },
      { id: 3, name: "Third Badge" },
      { id: 4, name: "Duplicate Name" },
    ]
  end

  let(:badge_rows) { badges.map { |badge| badge[:name].downcase } }
  let(:badges_query_result) do
    ::Migrations::Importer::DiscourseDB::QueryResult.new(rows: badge_rows, column_count: 1)
  end

  before do
    allow(discourse_db).to receive(:query_result).with(
      a_string_including("SELECT LOWER(name)"),
    ).and_return(badges_query_result)
  end

  describe "#find_available_name" do
    context "with unique names" do
      it "returns the sanitized name when available" do
        name = finder.find_available_name("New Badge")
        expect(name).to eq("New Badge")
      end

      it "strips whitespace from names" do
        name = finder.find_available_name("  Spaced  Name  ")
        expect(name).to eq("Spaced  Name")
      end

      it "handles Unicode characters" do
        name = finder.find_available_name("Café ☕")
        expect(name).to eq("Café ☕")
      end
    end

    context "with duplicate names" do
      it "adds suffix for duplicate name" do
        finder.find_available_name("Test")
        name = finder.find_available_name("Test")
        expect(name).to eq("Test_1")
      end

      it "increments suffixes sequentially" do
        finder.find_available_name("Test")
        finder.find_available_name("Test")
        name = finder.find_available_name("Test")
        expect(name).to eq("Test_2")
      end

      it "handles case-insensitive duplicates" do
        finder.find_available_name("Test")
        name = finder.find_available_name("TEST")
        expect(name).to eq("TEST_1")
      end
    end

    context "with existing badges" do
      it "avoids names that exist in database" do
        name = finder.find_available_name("Basic Badge")
        expect(name).to eq("Basic Badge_1")
      end

      it "handles multiple duplicates" do
        name1 = finder.find_available_name("Duplicate Name")
        name2 = finder.find_available_name("Duplicate Name")

        expect(name1).to eq("Duplicate Name_1")
        expect(name2).to eq("Duplicate Name_2")
      end
    end

    context "with length constraints" do
      it "truncates names longer than max length" do
        long_name = "A" * 95 + "1234567890"
        name = finder.find_available_name(long_name)
        expect(name).to eq("A" * 95 + "12345")
      end

      it "truncates and adds suffix when needed" do
        long_name = "A" * 90 + "1234567890"
        finder.find_available_name(long_name)
        name = finder.find_available_name(long_name)
        expect(name).to eq("A" * 90 + "12345678_1")
      end

      it "accepts single character names" do
        name = finder.find_available_name("A")
        expect(name).to eq("A")
      end
    end

    context "with empty or invalid names" do
      it "uses fallback name for empty string" do
        name = finder.find_available_name("")
        expect(name).to eq("Badge_1")
      end

      it "uses fallback name for whitespace only" do
        name = finder.find_available_name("   ")
        expect(name).to eq("Badge_1")
      end

      it "uses fallback name for nil" do
        name = finder.find_available_name(nil)
        expect(name).to eq("Badge_1")
      end

      it "increments fallback name suffix" do
        finder.find_available_name("")
        name = finder.find_available_name("")
        expect(name).to eq("Badge_2")
      end
    end

    context "with special characters" do
      it "preserves special characters in names" do
        name = finder.find_available_name("Test & Badge!")
        expect(name).to eq("Test & Badge!")
      end
    end
  end
end
