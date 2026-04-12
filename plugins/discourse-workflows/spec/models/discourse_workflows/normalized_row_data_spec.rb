# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTables::Facade::RowInput do
  fab!(:data_table) do
    Fabricate(
      :discourse_workflows_data_table,
      columns: [
        { "name" => "email", "type" => "string" },
        { "name" => "score", "type" => "number" },
      ],
    )
  end

  describe "with valid data" do
    subject(:model) do
      described_class.new(data_table:, data: { "email" => "a@b.com", "score" => "5" })
    end

    it "casts the column values" do
      expect(model.columns).to eq("email" => "a@b.com", "score" => 5)
    end
  end

  describe "with fill_missing" do
    subject(:model) do
      described_class.new(data_table:, data: { "email" => "a@b.com" }, fill_missing: true)
    end

    it "fills omitted columns with nil" do
      expect(model.columns).to eq("email" => "a@b.com", "score" => nil)
    end
  end

  describe "with unknown columns" do
    subject(:model) { described_class.new(data_table:, data: { "unknown" => "val" }) }

    it "is invalid" do
      expect(model).not_to be_valid
      expect(model.errors[:base]).to include(match(/Unknown column name/))
    end
  end

  describe "with invalid type" do
    subject(:model) { described_class.new(data_table:, data: { "score" => "not_a_number" }) }

    it "is invalid" do
      expect(model).not_to be_valid
      expect(model.errors[:base]).to include(match(/does not match column type/))
    end
  end
end
