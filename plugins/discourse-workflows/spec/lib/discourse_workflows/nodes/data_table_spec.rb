# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::DataTable::V1 do
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

  def execute_data_table(configuration)
    execute_node_result(configuration: configuration).primary_items(ports: described_class.ports)
  end

  describe "error handling" do
    it "raises when data table does not exist" do
      expect {
        execute_data_table(
          "operation" => "insert",
          "data_table_id" => "-1",
          "columns" => {
            "email" => "x",
          },
        )
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "raises for unknown column names" do
      expect {
        execute_data_table(
          "operation" => "insert",
          "data_table_id" => data_table.id.to_s,
          "columns" => {
            "nonexistent" => "test",
          },
        )
      }.to raise_error(ArgumentError, /Unknown column name/)
    end

    it "raises for unknown operations" do
      expect {
        execute_data_table("operation" => "truncate", "data_table_id" => data_table.id.to_s)
      }.to raise_error(ArgumentError, /Unknown operation/)
    end
  end

  describe "insert operation" do
    it "inserts a row and returns it" do
      items =
        execute_data_table(
          "operation" => "insert",
          "data_table_id" => data_table.id.to_s,
          "columns" => {
            "email" => "test@example.com",
            "score" => "42",
          },
        )

      expect(items.length).to eq(1)
      expect(items[0]["json"]).to include("email" => "test@example.com", "score" => 42)
      expect(count_data_table_rows(data_table)).to eq(1)
    end

    it "raises when the storage limit is exceeded" do
      allow(DiscourseWorkflows::DataTableSizeValidator).to receive(:within_limit?).and_return(false)

      expect {
        execute_data_table(
          "operation" => "insert",
          "data_table_id" => data_table.id.to_s,
          "columns" => {
            "email" => "test@example.com",
            "score" => "42",
          },
        )
      }.to raise_error(ArgumentError, "Data table storage limit exceeded")
    end
  end

  describe "get operation" do
    before do
      insert_data_table_row(data_table, "email" => "a@test.com", "score" => 10)
      insert_data_table_row(data_table, "email" => "b@test.com", "score" => 20)
    end

    it "returns each row as a separate output item" do
      items =
        execute_data_table(
          "operation" => "get",
          "data_table_id" => data_table.id.to_s,
          "filter_combinator" => "and",
          "filter" => [
            { "leftValue" => "score", "operator" => { "operation" => "gt" }, "rightValue" => "15" },
          ],
        )

      expect(items.length).to eq(1)
      expect(items[0]["json"]["email"]).to eq("b@test.com")
    end

    it "returns all rows without filters" do
      items = execute_data_table("operation" => "get", "data_table_id" => data_table.id.to_s)

      expect(items.length).to eq(2)
    end
  end

  describe "update operation" do
    fab!(:row) { insert_data_table_row(data_table, "email" => "up@test.com", "score" => 1) }

    it "updates matching rows" do
      items =
        execute_data_table(
          "operation" => "update",
          "data_table_id" => data_table.id.to_s,
          "filter" => [
            {
              "leftValue" => "email",
              "operator" => {
                "operation" => "equals",
              },
              "rightValue" => "up@test.com",
            },
          ],
          "columns" => {
            "score" => "99",
          },
        )

      expect(items[0]["json"]["updated_count"]).to eq(1)
      expect(find_data_table_row(data_table, row["id"])["score"]).to eq(99)
    end

    it "updates all rows without filter" do
      insert_data_table_row(data_table, "email" => "second@test.com", "score" => 2)

      items =
        execute_data_table(
          "operation" => "update",
          "data_table_id" => data_table.id.to_s,
          "columns" => {
            "score" => "77",
          },
        )

      expect(items[0]["json"]["updated_count"]).to eq(2)
    end

    it "raises when the storage limit is exceeded" do
      allow(DiscourseWorkflows::DataTableSizeValidator).to receive(:within_limit?).and_return(false)

      expect {
        execute_data_table(
          "operation" => "update",
          "data_table_id" => data_table.id.to_s,
          "filter" => [
            {
              "leftValue" => "email",
              "operator" => {
                "operation" => "equals",
              },
              "rightValue" => "up@test.com",
            },
          ],
          "columns" => {
            "score" => "99",
          },
        )
      }.to raise_error(ArgumentError, "Data table storage limit exceeded")
    end
  end

  describe "delete operation" do
    before { insert_data_table_row(data_table, "email" => "del@test.com", "score" => 5) }

    it "deletes matching rows" do
      items =
        execute_data_table(
          "operation" => "delete",
          "data_table_id" => data_table.id.to_s,
          "filter" => [
            {
              "leftValue" => "email",
              "operator" => {
                "operation" => "equals",
              },
              "rightValue" => "del@test.com",
            },
          ],
        )

      expect(items[0]["json"]["deleted_count"]).to eq(1)
      expect(count_data_table_rows(data_table)).to eq(0)
    end

    it "deletes all rows without filter" do
      insert_data_table_row(data_table, "email" => "del2@test.com", "score" => 10)

      items = execute_data_table("operation" => "delete", "data_table_id" => data_table.id.to_s)

      expect(items[0]["json"]["deleted_count"]).to eq(2)
      expect(count_data_table_rows(data_table)).to eq(0)
    end
  end

  describe "upsert operation" do
    it "inserts when no filter even if rows exist" do
      insert_data_table_row(data_table, "email" => "existing@test.com", "score" => 1)

      items =
        execute_data_table(
          "operation" => "upsert",
          "data_table_id" => data_table.id.to_s,
          "columns" => {
            "email" => "nf@test.com",
            "score" => "10",
          },
        )

      expect(items[0]["json"]["operation"]).to eq("insert")
      expect(count_data_table_rows(data_table)).to eq(2)
    end

    it "inserts when no match" do
      items =
        execute_data_table(
          "operation" => "upsert",
          "data_table_id" => data_table.id.to_s,
          "filter" => [
            {
              "leftValue" => "email",
              "operator" => {
                "operation" => "equals",
              },
              "rightValue" => "new@test.com",
            },
          ],
          "columns" => {
            "email" => "new@test.com",
            "score" => "50",
          },
        )

      expect(items[0]["json"]["operation"]).to eq("insert")
      expect(count_data_table_rows(data_table)).to eq(1)
    end

    it "updates when match exists" do
      row = insert_data_table_row(data_table, "email" => "exists@test.com", "score" => 10)

      items =
        execute_data_table(
          "operation" => "upsert",
          "data_table_id" => data_table.id.to_s,
          "filter" => [
            {
              "leftValue" => "email",
              "operator" => {
                "operation" => "equals",
              },
              "rightValue" => "exists@test.com",
            },
          ],
          "columns" => {
            "email" => "exists@test.com",
            "score" => "99",
          },
        )

      expect(items[0]["json"]["operation"]).to eq("update")
      expect(items[0]["json"]["count"]).to eq(1)
      expect(find_data_table_row(data_table, row["id"])["score"]).to eq(99)
    end

    it "raises when the storage limit is exceeded" do
      allow(DiscourseWorkflows::DataTableSizeValidator).to receive(:within_limit?).and_return(false)

      expect {
        execute_data_table(
          "operation" => "upsert",
          "data_table_id" => data_table.id.to_s,
          "filter" => [
            {
              "leftValue" => "email",
              "operator" => {
                "operation" => "equals",
              },
              "rightValue" => "new@test.com",
            },
          ],
          "columns" => {
            "email" => "new@test.com",
            "score" => "50",
          },
        )
      }.to raise_error(ArgumentError, "Data table storage limit exceeded")
    end
  end
end
