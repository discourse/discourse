# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTable do
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_length_of(:name).is_at_most(100) }

  describe "name uniqueness" do
    fab!(:data_table, :discourse_workflows_data_table)

    it "rejects duplicate names" do
      dupe = described_class.new(name: data_table.name, columns: [])
      expect(dupe).not_to be_valid
      expect(dupe.errors[:name]).to include("has already been taken")
    end
  end

  describe "name format" do
    it "allows alphanumeric names with underscores and spaces" do
      table = described_class.new(name: "My Table 1", columns: [])
      expect(table).to be_valid
    end

    it "rejects names starting with a number" do
      table = described_class.new(name: "1table", columns: [])
      expect(table).not_to be_valid
    end
  end

  describe "columns validation" do
    it "accepts valid column definitions" do
      table =
        described_class.new(name: "test", columns: [{ "name" => "email", "type" => "string" }])
      expect(table).to be_valid
    end

    it "rejects columns with invalid types" do
      table =
        described_class.new(name: "test", columns: [{ "name" => "field", "type" => "invalid" }])
      expect(table).not_to be_valid
    end

    it "rejects columns with reserved names" do
      table = described_class.new(name: "test", columns: [{ "name" => "id", "type" => "string" }])
      expect(table).not_to be_valid
    end

    it "rejects duplicate column names" do
      table =
        described_class.new(
          name: "test",
          columns: [
            { "name" => "email", "type" => "string" },
            { "name" => "email", "type" => "number" },
          ],
        )
      expect(table).not_to be_valid
    end

    it "rejects columns with names exceeding 63 characters" do
      table =
        described_class.new(name: "test", columns: [{ "name" => "a" * 64, "type" => "string" }])
      expect(table).not_to be_valid
    end
  end
end
