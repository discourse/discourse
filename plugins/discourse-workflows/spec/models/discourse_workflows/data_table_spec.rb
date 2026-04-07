# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTable do
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

  describe "#columns" do
    fab!(:data_table) do
      Fabricate(
        :discourse_workflows_data_table,
        columns: [{ "name" => "email", "type" => "string" }],
      )
    end

    it "returns columns from the storage table" do
      columns = data_table.columns
      expect(columns.map { |c| c["name"] }).to include("email")
    end
  end
end
