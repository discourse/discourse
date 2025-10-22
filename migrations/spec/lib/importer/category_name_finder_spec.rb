# frozen_string_literal: true

RSpec.describe Migrations::Importer::CategoryNameFinder do
  subject(:finder) { described_class.new(shared_data) }

  let(:discourse_db) { ::Migrations::Importer::DiscourseDB.new }
  let(:shared_data) { ::Migrations::Importer::SharedData.new(discourse_db) }

  before do
    @root1 = Fabricate(:category, name: "Root Category")
    @root2 = Fabricate(:category, name: "Another Root")
    @root3 = Fabricate(:category, name: "Third Root")

    @child1_1 = Fabricate(:category, name: "Child One", parent_category: @root1)
    @child1_2 = Fabricate(:category, name: "Child Two", parent_category: @root1)
    @child1_3 = Fabricate(:category, name: "Duplicate Name", parent_category: @root1)

    @child2_1 = Fabricate(:category, name: "Child One", parent_category: @root2)
    @child2_2 = Fabricate(:category, name: "Duplicate Name", parent_category: @root2)
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
        name1 = finder.find_available_name("Child One", @root1.id)
        name2 = finder.find_available_name("Child One", @root2.id)
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
        expect(name).to eq("Root Category_2")
      end

      it "avoids names that exist in specific parent" do
        name = finder.find_available_name("Child Two", @root1.id)
        expect(name).to eq("Child Two_2")
      end

      it "allows reusing child names at root level" do
        name = finder.find_available_name("Child One", nil)
        expect(name).to eq("Child One")
      end

      it "handles multiple duplicates across parents" do
        # "Duplicate Name" exists in root1 and root2
        name1 = finder.find_available_name("Duplicate Name", @root1.id)
        name2 = finder.find_available_name("Duplicate Name", @root2.id)
        name3 = finder.find_available_name("Duplicate Name", @root3.id)

        expect(name1).to eq("Duplicate Name_2")
        expect(name2).to eq("Duplicate Name_2")
        expect(name3).to eq("Duplicate Name")
      end
    end

    context "with length constraints" do
      it "truncates names longer than max length" do
        long_name = "A" * 60
        name = finder.find_available_name(long_name, nil)
        expect(name.length).to eq(50)
      end

      it "truncates and adds suffix when needed" do
        long_name = "A" * 50
        finder.find_available_name(long_name, nil)
        name = finder.find_available_name(long_name, nil)
        expect(name).to match(/\AA+_2\z/)
        expect(name.length).to eq(50)
      end

      it "handles grapheme clusters when truncating" do
        name_with_emoji = "Category 👨‍👩‍👧‍👦" * 10
        name = finder.find_available_name(name_with_emoji, nil)
        expect(name.length).to be <= 50
      end

      it "accepts single character names" do
        name = finder.find_available_name("A", nil)
        expect(name).to eq("A")
      end
    end

    context "with empty or invalid names" do
      it "uses fallback name for empty string" do
        name = finder.find_available_name("", nil)
        expect(name).to eq("category_1")
      end

      it "uses fallback name for whitespace only" do
        name = finder.find_available_name("   ", nil)
        expect(name).to eq("category_1")
      end

      it "uses fallback name for nil" do
        name = finder.find_available_name(nil, nil)
        expect(name).to eq("category_1")
      end

      it "increments fallback name suffix" do
        finder.find_available_name("", nil)
        name = finder.find_available_name("", nil)
        expect(name).to eq("category_2")
      end

      it "uses separate fallback counters per parent" do
        finder.find_available_name("", @root1.id)
        finder.find_available_name("", @root2.id)
        name1 = finder.find_available_name("", @root1.id)
        name2 = finder.find_available_name("", @root2.id)

        expect(name1).to eq("category_2")
        expect(name2).to eq("category_2")
      end
    end

    context "with parent scoping" do
      it "maintains separate suffix counters per parent" do
        finder.find_available_name("Test", @root1.id)
        finder.find_available_name("Test", @root1.id)
        finder.find_available_name("Test", @root2.id)

        name1 = finder.find_available_name("Test", @root1.id)
        name2 = finder.find_available_name("Test", @root2.id)

        expect(name1).to eq("Test_3")
        expect(name2).to eq("Test_2")
      end

      it "maintains separate truncation caches per parent" do
        long_name = "A" * 50

        finder.find_available_name(long_name, @root1.id)
        name1 = finder.find_available_name(long_name, @root1.id)

        finder.find_available_name(long_name, @root2.id)
        name2 = finder.find_available_name(long_name, @root2.id)

        expect(name1).to eq(name2)
      end
    end

    context "with special characters" do
      it "preserves special characters in names" do
        name = finder.find_available_name("Test & Category!", nil)
        expect(name).to eq("Test & Category!")
      end

      it "handles names with underscores" do
        finder.find_available_name("Test_Name", nil)
        name = finder.find_available_name("Test_Name", nil)
        expect(name).to eq("Test_Name_2")
      end
    end
  end
end
