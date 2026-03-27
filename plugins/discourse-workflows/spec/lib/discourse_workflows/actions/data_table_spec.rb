# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Actions::DataTable::V1 do
  fab!(:data_table) do
    Fabricate(
      :discourse_workflows_data_table,
      name: "contacts",
      columns: [
        { "name" => "email", "type" => "string" },
        { "name" => "score", "type" => "number" },
      ],
    )
  end

  let(:context) { { "trigger" => {} } }
  let(:storage_limit_error) { DiscourseWorkflows::DataTableValidationError.new("quota full") }

  describe ".identifier" do
    it "returns action:data_table" do
      expect(described_class.identifier).to eq("action:data_table")
    end
  end

  describe "error handling" do
    it "raises when data table does not exist" do
      instance = described_class.new(configuration: {})
      config = {
        "operation" => "insert",
        "data_table_id" => "-1",
        "columns" => {
          "email" => "test@test.com",
        },
      }

      expect {
        instance.execute_single(context, item: { "json" => {} }, config: config)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "raises for unknown column names" do
      instance = described_class.new(configuration: {})
      config = {
        "operation" => "insert",
        "data_table_id" => data_table.id.to_s,
        "columns" => {
          "nonexistent" => "test",
        },
      }

      expect {
        instance.execute_single(context, item: { "json" => {} }, config: config)
      }.to raise_error(DiscourseWorkflows::DataTableValidationError, /Unknown column name/)
    end

    it "raises for unknown operations" do
      instance = described_class.new(configuration: {})
      config = { "operation" => "truncate", "data_table_id" => data_table.id.to_s }

      expect {
        instance.execute_single(context, item: { "json" => {} }, config: config)
      }.to raise_error(ArgumentError, /Unknown operation/)
    end
  end

  describe "insert operation" do
    it "inserts a row and returns it" do
      instance = described_class.new(configuration: {})
      config = {
        "operation" => "insert",
        "data_table_id" => data_table.id.to_s,
        "columns" => {
          "email" => "test@example.com",
          "score" => "42",
        },
      }

      result = instance.execute_single(context, item: { "json" => {} }, config: config)
      expect(result).to include("email" => "test@example.com", "score" => 42)
      expect(count_data_table_rows(data_table)).to eq(1)
    end

    it "raises when the storage limit is exceeded" do
      allow(DiscourseWorkflows::DataTableSizeValidator).to receive(:validate_size!).and_raise(
        storage_limit_error,
      )

      instance = described_class.new(configuration: {})
      config = {
        "operation" => "insert",
        "data_table_id" => data_table.id.to_s,
        "columns" => {
          "email" => "test@example.com",
          "score" => "42",
        },
      }

      expect {
        instance.execute_single(context, item: { "json" => {} }, config: config)
      }.to raise_error(DiscourseWorkflows::DataTableValidationError, storage_limit_error.message)
    end
  end

  describe "get operation" do
    before do
      insert_data_table_row(data_table, "email" => "a@test.com", "score" => 10)
      insert_data_table_row(data_table, "email" => "b@test.com", "score" => 20)
    end

    it "returns matching rows" do
      instance = described_class.new(configuration: {})
      config = {
        "operation" => "get",
        "data_table_id" => data_table.id.to_s,
        "filter" => {
          "type" => "and",
          "filters" => [{ "columnName" => "score", "condition" => "gt", "value" => "15" }],
        },
      }

      result = instance.execute_single(context, item: { "json" => {} }, config: config)
      expect(result["rows"].length).to eq(1)
      expect(result["rows"][0]["email"]).to eq("b@test.com")
    end

    it "accepts filter JSON strings from the property engine editor" do
      instance = described_class.new(configuration: {})
      config = {
        "operation" => "get",
        "data_table_id" => data_table.id.to_s,
        "filter" =>
          '{"type":"and","filters":[{"columnName":"score","condition":"gt","value":"15"}]}',
      }

      result = instance.execute_single(context, item: { "json" => {} }, config: config)

      expect(result["rows"].length).to eq(1)
      expect(result["rows"][0]["email"]).to eq("b@test.com")
    end

    it "returns all rows without filters" do
      instance = described_class.new(configuration: {})
      config = { "operation" => "get", "data_table_id" => data_table.id.to_s }

      result = instance.execute_single(context, item: { "json" => {} }, config: config)
      expect(result["rows"].length).to eq(2)
    end
  end

  describe "update operation" do
    fab!(:row) { insert_data_table_row(data_table, "email" => "up@test.com", "score" => 1) }

    it "updates matching rows" do
      instance = described_class.new(configuration: {})
      config = {
        "operation" => "update",
        "data_table_id" => data_table.id.to_s,
        "filter" => {
          "type" => "and",
          "filters" => [{ "columnName" => "email", "condition" => "eq", "value" => "up@test.com" }],
        },
        "columns" => {
          "score" => "99",
        },
      }

      result = instance.execute_single(context, item: { "json" => {} }, config: config)
      expect(result["updated_count"]).to eq(1)
      expect(find_data_table_row(data_table, row["id"])["score"]).to eq(99)
    end

    it "raises when the storage limit is exceeded" do
      allow(DiscourseWorkflows::DataTableSizeValidator).to receive(:validate_size!).and_raise(
        storage_limit_error,
      )

      instance = described_class.new(configuration: {})
      config = {
        "operation" => "update",
        "data_table_id" => data_table.id.to_s,
        "filter" => {
          "type" => "and",
          "filters" => [{ "columnName" => "email", "condition" => "eq", "value" => "up@test.com" }],
        },
        "columns" => {
          "score" => "99",
        },
      }

      expect {
        instance.execute_single(context, item: { "json" => {} }, config: config)
      }.to raise_error(DiscourseWorkflows::DataTableValidationError, storage_limit_error.message)
    end
  end

  describe "delete operation" do
    before { insert_data_table_row(data_table, "email" => "del@test.com", "score" => 5) }

    it "deletes matching rows" do
      instance = described_class.new(configuration: {})
      config = {
        "operation" => "delete",
        "data_table_id" => data_table.id.to_s,
        "filter" => {
          "type" => "and",
          "filters" => [
            { "columnName" => "email", "condition" => "eq", "value" => "del@test.com" },
          ],
        },
      }

      result = instance.execute_single(context, item: { "json" => {} }, config: config)
      expect(result["deleted_count"]).to eq(1)
      expect(count_data_table_rows(data_table)).to eq(0)
    end
  end

  describe "upsert operation" do
    it "inserts when no match" do
      instance = described_class.new(configuration: {})
      config = {
        "operation" => "upsert",
        "data_table_id" => data_table.id.to_s,
        "filter" => {
          "type" => "and",
          "filters" => [
            { "columnName" => "email", "condition" => "eq", "value" => "new@test.com" },
          ],
        },
        "columns" => {
          "email" => "new@test.com",
          "score" => "50",
        },
      }

      result = instance.execute_single(context, item: { "json" => {} }, config: config)
      expect(result["operation"]).to eq("insert")
      expect(count_data_table_rows(data_table)).to eq(1)
    end

    it "updates when match exists" do
      row = insert_data_table_row(data_table, "email" => "exists@test.com", "score" => 10)

      instance = described_class.new(configuration: {})
      config = {
        "operation" => "upsert",
        "data_table_id" => data_table.id.to_s,
        "filter" => {
          "type" => "and",
          "filters" => [
            { "columnName" => "email", "condition" => "eq", "value" => "exists@test.com" },
          ],
        },
        "columns" => {
          "email" => "exists@test.com",
          "score" => "99",
        },
      }

      result = instance.execute_single(context, item: { "json" => {} }, config: config)
      expect(result["operation"]).to eq("update")
      expect(result["count"]).to eq(1)
      expect(find_data_table_row(data_table, row["id"])["score"]).to eq(99)
    end

    it "raises when the storage limit is exceeded" do
      allow(DiscourseWorkflows::DataTableSizeValidator).to receive(:validate_size!).and_raise(
        storage_limit_error,
      )

      instance = described_class.new(configuration: {})
      config = {
        "operation" => "upsert",
        "data_table_id" => data_table.id.to_s,
        "filter" => {
          "type" => "and",
          "filters" => [
            { "columnName" => "email", "condition" => "eq", "value" => "new@test.com" },
          ],
        },
        "columns" => {
          "email" => "new@test.com",
          "score" => "50",
        },
      }

      expect {
        instance.execute_single(context, item: { "json" => {} }, config: config)
      }.to raise_error(DiscourseWorkflows::DataTableValidationError, storage_limit_error.message)
    end
  end
end
