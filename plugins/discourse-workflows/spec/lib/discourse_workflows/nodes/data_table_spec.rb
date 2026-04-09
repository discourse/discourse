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

  let(:input_items) { [{ "json" => {} }] }

  def execute(configuration)
    resolver = DiscourseWorkflows::ExpressionResolver.new({ "$json" => {} })
    result =
      described_class.new(configuration: configuration).execute(
        DiscourseWorkflows::NodeExecutionContext.new(
          input_items: input_items,
          node_context: {
          },
          resolver: resolver,
          configuration: configuration,
          configuration_schema: described_class.configuration_schema,
        ),
      )
    result[0]
  end

  describe ".identifier" do
    it "returns action:data_table" do
      expect(described_class.identifier).to eq("action:data_table")
    end
  end

  describe ".property_i18n_scope" do
    it "uses the data_table_node translation namespace" do
      expect(described_class.property_i18n_scope).to eq("data_table_node")
    end
  end

  describe ".operation_label_key" do
    it "uses the nested operations translation key" do
      expect(described_class.operation_label_key("insert")).to eq(
        "discourse_workflows.data_table_node.operations.insert",
      )
    end
  end

  describe "error handling" do
    it "raises when data table does not exist" do
      expect {
        execute("operation" => "insert", "data_table_id" => "-1", "columns" => { "email" => "x" })
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "raises for unknown column names" do
      expect {
        execute(
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
        execute("operation" => "truncate", "data_table_id" => data_table.id.to_s)
      }.to raise_error(ArgumentError, /Unknown operation/)
    end
  end

  describe "insert operation" do
    it "inserts a row and returns it" do
      items =
        execute(
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
        execute(
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
        execute(
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
      items = execute("operation" => "get", "data_table_id" => data_table.id.to_s)

      expect(items.length).to eq(2)
    end
  end

  describe "update operation" do
    fab!(:row) { insert_data_table_row(data_table, "email" => "up@test.com", "score" => 1) }

    it "updates matching rows" do
      items =
        execute(
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
        execute(
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
        execute(
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
        execute(
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

      items = execute("operation" => "delete", "data_table_id" => data_table.id.to_s)

      expect(items[0]["json"]["deleted_count"]).to eq(2)
      expect(count_data_table_rows(data_table)).to eq(0)
    end
  end

  describe "upsert operation" do
    it "inserts when no filter even if rows exist" do
      insert_data_table_row(data_table, "email" => "existing@test.com", "score" => 1)

      items =
        execute(
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
        execute(
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
        execute(
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
        execute(
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
