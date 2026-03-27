# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTable do
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_length_of(:name).is_at_most(100) }

  describe "name uniqueness" do
    fab!(:data_table, :discourse_workflows_data_table)

    it "rejects duplicate names" do
      dupe = described_class.new(name: data_table.name)
      expect(dupe).not_to be_valid
      expect(dupe.errors[:name]).to include("has already been taken")
    end
  end

  describe "name format" do
    it "allows alphanumeric names with underscores and spaces" do
      table = described_class.new(name: "My Table 1")
      expect(table).to be_valid
    end

    it "rejects names starting with a number" do
      table = described_class.new(name: "1table")
      expect(table).not_to be_valid
    end
  end

  describe "column validation" do
    it "rejects duplicate column names" do
      table = described_class.new(name: "test")
      table.columns.build(name: "email", column_type: "string", position: 0)
      table.columns.build(name: "email", column_type: "number", position: 1)

      expect(table).not_to be_valid
      expect(table.errors[:columns]).to include("name must be unique")
    end

    it "rejects duplicate column positions" do
      table = described_class.new(name: "test")
      table.columns.build(name: "email", column_type: "string", position: 0)
      table.columns.build(name: "score", column_type: "number", position: 0)

      expect(table).not_to be_valid
      expect(table.errors[:columns]).to include("position must be unique")
    end
  end
end
