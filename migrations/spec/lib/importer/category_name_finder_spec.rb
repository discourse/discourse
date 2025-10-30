# frozen_string_literal: true

RSpec.describe Migrations::Importer::CategoryNameFinder do
  subject(:finder) { described_class.new(shared_data) }

  let(:discourse_db) { ::Migrations::Importer::DiscourseDB.new }
  let(:shared_data) { ::Migrations::Importer::SharedData.new(discourse_db) }

  let(:categories) do
    [
      { id: 1, parent_id: nil, name: "Root Category" },
      { id: 2, parent_id: nil, name: "Another Root" },
      { id: 3, parent_id: nil, name: "Third Root" },
      { id: 4, parent_id: 1, name: "Child One" },
      { id: 5, parent_id: 1, name: "Child Two" },
      { id: 6, parent_id: 1, name: "Duplicate Name" },
      { id: 7, parent_id: 2, name: "Child One" },
      { id: 8, parent_id: 2, name: "Duplicate Name" },
    ]
  end
  let(:root1_id) { categories[0][:id] }
  let(:root2_id) { categories[1][:id] }
  let(:root3_id) { categories[2][:id] }

  let(:category_rows) do
    categories.map { |category| [category[:parent_id], category[:name].downcase] }
  end
  let(:categories_query_result) do
    ::Migrations::Importer::DiscourseDB::QueryResult.new(rows: category_rows, column_count: 2)
  end

  before do
    allow(discourse_db).to receive(:query_result).with(
      a_string_including("SELECT parent_category_id, LOWER(name)"),
    ).and_return(categories_query_result)
  end

  describe "#find_available_name" do
    context "with unique names" do
      it "returns the sanitized name when available" do
        name = finder.find_available_name("New Category", nil)
        expect(name).to eq("New Category")
      end

      it "strips whitespace from names" do
        name = finder.find_available_name("  Spaced  Name  ", nil)
        expect(name).to eq("Spaced  Name")
      end

      it "handles Unicode characters" do
        name = finder.find_available_name("Café ☕", nil)
        expect(name).to eq("Café ☕")
      end
    end

    context "with duplicate names" do
      it "adds suffix for duplicate name in same parent" do
        finder.find_available_name("Test", nil)
        name = finder.find_available_name("Test", nil)
        expect(name).to eq("Test_1")
      end

      it "allows same name in different parents" do
        name1 = finder.find_available_name("Child One", root1_id)
        name2 = finder.find_available_name("Child One", root2_id)
        expect(name1).to eq("Child One_1")
        expect(name2).to eq("Child One_1")
      end

      it "allows same name at root level vs child level" do
        name = finder.find_available_name("Duplicate Name", nil)
        expect(name).to eq("Duplicate Name")
      end

      it "increments suffixes sequentially" do
        finder.find_available_name("Test", nil)
        finder.find_available_name("Test", nil)
        name = finder.find_available_name("Test", nil)
        expect(name).to eq("Test_2")
      end

      it "handles case-insensitive duplicates" do
        finder.find_available_name("Test", nil)
        name = finder.find_available_name("TEST", nil)
        expect(name).to eq("TEST_1")
      end
    end

    context "with existing categories" do
      it "avoids names that exist at root level" do
        name = finder.find_available_name("Root Category", nil)
        expect(name).to eq("Root Category_1")
      end

      it "avoids names that exist in specific parent" do
        name = finder.find_available_name("Child Two", root1_id)
        expect(name).to eq("Child Two_1")
      end

      it "allows reusing child names at root level" do
        name = finder.find_available_name("Child One", nil)
        expect(name).to eq("Child One")
      end

      it "handles multiple duplicates across parents" do
        # "Duplicate Name" exists in root1 and root2
        name1 = finder.find_available_name("Duplicate Name", root1_id)
        name2 = finder.find_available_name("Duplicate Name", root2_id)
        name3 = finder.find_available_name("Duplicate Name", root3_id)

        expect(name1).to eq("Duplicate Name_1")
        expect(name2).to eq("Duplicate Name_1")
        expect(name3).to eq("Duplicate Name")
      end
    end

    context "with length constraints" do
      it "truncates names longer than max length" do
        long_name = "A" * 45 + "1234567890"
        name = finder.find_available_name(long_name, nil)
        expect(name).to eq("A" * 45 + "12345")
      end

      it "truncates and adds suffix when needed" do
        long_name = "A" * 40 + "1234567890"
        finder.find_available_name(long_name, nil)
        name = finder.find_available_name(long_name, nil)
        expect(name).to eq("A" * 40 + "12345678_1")
      end

      it "accepts single character names" do
        name = finder.find_available_name("A", nil)
        expect(name).to eq("A")
      end
    end

    context "with empty or invalid names" do
      it "uses fallback name for empty string" do
        name = finder.find_available_name("", nil)
        expect(name).to eq("Category_1")
      end

      it "uses fallback name for whitespace only" do
        name = finder.find_available_name("   ", nil)
        expect(name).to eq("Category_1")
      end

      it "uses fallback name for nil" do
        name = finder.find_available_name(nil, nil)
        expect(name).to eq("Category_1")
      end

      it "increments fallback name suffix" do
        finder.find_available_name("", nil)
        name = finder.find_available_name("", nil)
        expect(name).to eq("Category_2")
      end

      it "uses separate fallback counters per parent" do
        finder.find_available_name("", root1_id)
        finder.find_available_name("", root2_id)
        name1 = finder.find_available_name("", root1_id)
        name2 = finder.find_available_name("", root2_id)

        expect(name1).to eq("Category_2")
        expect(name2).to eq("Category_2")
      end
    end

    context "with parent scoping" do
      it "maintains separate suffix counters per parent" do
        finder.find_available_name("Test", root1_id)
        finder.find_available_name("Test", root1_id)
        finder.find_available_name("Test", root2_id)

        name1 = finder.find_available_name("Test", root1_id)
        name2 = finder.find_available_name("Test", root2_id)

        expect(name1).to eq("Test_2")
        expect(name2).to eq("Test_1")
      end
    end

    context "with special characters" do
      it "preserves special characters in names" do
        name = finder.find_available_name("Test & Category!", nil)
        expect(name).to eq("Test & Category!")
      end
    end
  end
end
