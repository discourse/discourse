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
    execute_node_output(configuration: configuration).first
  end

  def execute_data_table_with_item(configuration, item)
    execute_node_output(configuration: configuration, item: item).first
  end

  def filter_condition(column_name, operation, value: nil, type: "string")
    single_value = %w[empty notEmpty true false].include?(operation)

    {
      "columnName" => column_name,
      "operator" => {
        "type" => type,
        "operation" => operation,
        "singleValue" => single_value,
      },
      "value" => value,
    }
  end

  describe ".load_options_context" do
    def load_options(filter: nil)
      context =
        DiscourseWorkflows::LoadOptionsContext.new(
          method_name: "data_tables",
          filter: filter,
          node_class: described_class,
        )

      described_class.load_options_context(context)
    end

    it "marks reserved columns" do
      tables = load_options
      table_meta = tables.find { |dt| dt[:id] == data_table.id }
      column_names_reserved = table_meta[:columns].select { |c| c[:reserved] }.map { |c| c[:name] }

      expect(column_names_reserved).to contain_exactly("id", "created_at", "updated_at")
      expect(table_meta[:columns].find { |c| c[:name] == "email" }).not_to have_key(:reserved)
    end

    it "filters data tables by the filter term" do
      Fabricate(:discourse_workflows_data_table, name: "projects")

      expect(load_options(filter: "cont").map { |table| table[:id] }).to contain_exactly(
        data_table.id,
      )
    end
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
      }.to raise_error(DiscourseWorkflows::NodeError, /Unknown column name/)
    end

    it "raises invalid row errors with the node error prefix" do
      expect {
        execute_data_table(
          "operation" => "insert",
          "data_table_id" => data_table.id.to_s,
          "columns" => {
            "score" => "not-a-number",
          },
        )
      }.to raise_error(DiscourseWorkflows::NodeError, /Invalid row: Value 'not-a-number'/)
    end

    it "raises invalid query errors with the node error prefix" do
      expect {
        execute_data_table(
          "operation" => "get",
          "data_table_id" => data_table.id.to_s,
          "filter" => [filter_condition("nonexistent", "equals", value: "test")],
        )
      }.to raise_error(DiscourseWorkflows::NodeError, /Invalid query: Unknown column name/)
    end

    it "raises for unknown operations" do
      expect {
        execute_data_table("operation" => "truncate", "data_table_id" => data_table.id.to_s)
      }.to raise_error(DiscourseWorkflows::NodeError, /Unknown operation/)
    end
  end

  describe "insert operation" do
    it "raises when the storage limit is exceeded" do
      allow(DiscourseWorkflows::DataTables::Facade).to receive(:within_storage_limit?).and_return(
        false,
      )

      expect {
        execute_data_table(
          "operation" => "insert",
          "data_table_id" => data_table.id.to_s,
          "columns" => {
            "email" => "test@example.com",
            "score" => "42",
          },
        )
      }.to raise_error(DiscourseWorkflows::NodeError, "Data table storage limit exceeded")
    end

    context "when mapping_mode is auto" do
      it "picks matching keys from the incoming item JSON" do
        items =
          execute_data_table_with_item(
            {
              "operation" => "insert",
              "data_table_id" => data_table.id.to_s,
              "mapping_mode" => "auto",
            },
            { "json" => { "email" => "auto@example.com", "score" => 7, "ignored" => "value" } },
          )

        expect(items[0]["json"]).to include("email" => "auto@example.com", "score" => 7)
        expect(count_data_table_rows(data_table)).to eq(1)
      end

      it "ignores keys whose case does not match a column name" do
        items =
          execute_data_table_with_item(
            {
              "operation" => "insert",
              "data_table_id" => data_table.id.to_s,
              "mapping_mode" => "auto",
            },
            { "json" => { "Email" => "mismatch@example.com", "email" => "ok@example.com" } },
          )

        expect(items[0]["json"]).to include("email" => "ok@example.com")
        expect(items[0]["json"]).not_to have_key("Email")
      end

      it "inserts each input item and preserves item pairing" do
        items =
          execute_node_output(
            configuration: {
              "operation" => "insert",
              "data_table_id" => data_table.id.to_s,
              "mapping_mode" => "auto",
            },
            input_items: [
              { "json" => { "email" => "first@example.com", "score" => 1 } },
              { "json" => { "email" => "second@example.com", "score" => 2 } },
            ],
          ).first

        expect(items.map { |item| item["json"].slice("email", "score") }).to eq(
          [
            { "email" => "first@example.com", "score" => 1 },
            { "email" => "second@example.com", "score" => 2 },
          ],
        )
        expect(items.map { |item| item["pairedItem"] }).to eq([{ "item" => 0 }, { "item" => 1 }])
        expect(count_data_table_rows(data_table)).to eq(2)
      end
    end
  end

  describe "get operation" do
    before do
      insert_data_table_row(data_table, "email" => "alice@example.com", "score" => 10)
      insert_data_table_row(data_table, "email" => "bob@test.com", "score" => 20)
    end

    it "resolves filters for each input item and preserves item pairing" do
      items =
        execute_node_output(
          configuration: {
            "operation" => "get",
            "data_table_id" => data_table.id.to_s,
            "filter" => [filter_condition("email", "contains", value: "={{ $json.domain }}")],
            "sort_column" => "email",
            "sort_direction" => "asc",
          },
          input_items: [
            { "json" => { "domain" => "example.com" } },
            { "json" => { "domain" => "test.com" } },
          ],
        ).first

      expect(items.map { |item| item["json"]["email"] }).to eq(%w[alice@example.com bob@test.com])
      expect(items.map { |item| item["pairedItem"] }).to eq([{ "item" => 0 }, { "item" => 1 }])
    end

    it "preserves item pairing when one input item returns multiple rows" do
      items =
        execute_node_output(
          configuration: {
            "operation" => "get",
            "data_table_id" => data_table.id.to_s,
            "sort_column" => "email",
            "sort_direction" => "asc",
          },
          input_items: [{ "json" => {} }],
        ).first

      expect(items.map { |item| item["json"]["email"] }).to eq(%w[alice@example.com bob@test.com])
      expect(items.map { |item| item["pairedItem"] }).to eq([{ "item" => 0 }, { "item" => 0 }])
    end

    it "defaults to the maximum result limit" do
      99.times do |index|
        insert_data_table_row(data_table, "email" => "extra-#{index}@example.com", "score" => index)
      end

      items =
        execute_data_table(
          "operation" => "get",
          "data_table_id" => data_table.id.to_s,
          "sort_column" => "email",
          "sort_direction" => "asc",
        )

      expect(items.size).to eq(DiscourseWorkflows::DataTables::Facade::MAX_LIMIT)
    end

    it "treats empty as null only" do
      insert_data_table_row(data_table, "email" => nil, "score" => 30)
      insert_data_table_row(data_table, "email" => "", "score" => 40)

      items =
        execute_data_table(
          "operation" => "get",
          "data_table_id" => data_table.id.to_s,
          "filter" => [filter_condition("email", "empty")],
        )

      expect(items.map { |item| item["json"]["email"] }).to contain_exactly(nil)
    end

    it "treats empty strings as not empty" do
      insert_data_table_row(data_table, "email" => nil, "score" => 30)
      insert_data_table_row(data_table, "email" => "", "score" => 40)

      items =
        execute_data_table(
          "operation" => "get",
          "data_table_id" => data_table.id.to_s,
          "filter" => [filter_condition("email", "notEmpty")],
        )

      expect(items.map { |item| item["json"]["email"] }).to contain_exactly(
        "alice@example.com",
        "bob@test.com",
        "",
      )
    end
  end

  describe "update operation" do
    fab!(:row) { insert_data_table_row(data_table, "email" => "up@test.com", "score" => 1) }

    it "requires a filter" do
      insert_data_table_row(data_table, "email" => "second@test.com", "score" => 2)

      expect {
        execute_data_table(
          "operation" => "update",
          "data_table_id" => data_table.id.to_s,
          "columns" => {
            "score" => "77",
          },
        )
      }.to raise_error(DiscourseWorkflows::NodeError, /Filter must not be empty/)
    end

    it "updates matching rows and returns the updated rows" do
      insert_data_table_row(data_table, "email" => "second@test.com", "score" => 2)

      items =
        execute_data_table(
          "operation" => "update",
          "data_table_id" => data_table.id.to_s,
          "filter" => [filter_condition("email", "equals", value: "up@test.com")],
          "columns" => {
            "score" => "77",
          },
        )

      expect(items.map { |item| item["json"].slice("email", "score") }).to eq(
        [{ "email" => "up@test.com", "score" => 77 }],
      )
      expect(count_data_table_rows(data_table)).to eq(2)
    end

    it "raises when the storage limit is exceeded" do
      allow(DiscourseWorkflows::DataTables::Facade).to receive(:within_storage_limit?).and_return(
        false,
      )

      expect {
        execute_data_table(
          "operation" => "update",
          "data_table_id" => data_table.id.to_s,
          "filter" => [filter_condition("email", "equals", value: "up@test.com")],
          "columns" => {
            "score" => "99",
          },
        )
      }.to raise_error(DiscourseWorkflows::NodeError, "Data table storage limit exceeded")
    end
  end

  describe "delete operation" do
    before { insert_data_table_row(data_table, "email" => "del@test.com", "score" => 5) }

    it "requires a filter" do
      insert_data_table_row(data_table, "email" => "del2@test.com", "score" => 10)

      expect {
        execute_data_table("operation" => "delete", "data_table_id" => data_table.id.to_s)
      }.to raise_error(DiscourseWorkflows::NodeError, /Filter must not be empty/)
    end

    it "deletes matching rows and returns the deleted rows" do
      insert_data_table_row(data_table, "email" => "del2@test.com", "score" => 10)

      items =
        execute_data_table(
          "operation" => "delete",
          "data_table_id" => data_table.id.to_s,
          "filter" => [filter_condition("email", "equals", value: "del@test.com")],
        )

      expect(items.map { |item| item["json"].slice("email", "score") }).to eq(
        [{ "email" => "del@test.com", "score" => 5 }],
      )
      expect(count_data_table_rows(data_table)).to eq(1)
    end

    it "deletes when storage is over the limit" do
      allow(DiscourseWorkflows::DataTables::Facade).to receive(:within_storage_limit?).and_return(
        false,
      )

      items =
        execute_data_table(
          "operation" => "delete",
          "data_table_id" => data_table.id.to_s,
          "filter" => [filter_condition("email", "equals", value: "del@test.com")],
        )

      expect(items.map { |item| item["json"].slice("email", "score") }).to eq(
        [{ "email" => "del@test.com", "score" => 5 }],
      )
      expect(count_data_table_rows(data_table)).to eq(0)
    end
  end

  describe "row_exists operation" do
    before { insert_data_table_row(data_table, "email" => "alice@example.com", "score" => 10) }

    it "emits the input item unchanged when at least one row matches" do
      items =
        execute_data_table_with_item(
          {
            "operation" => "row_exists",
            "data_table_id" => data_table.id.to_s,
            "filter" => [filter_condition("email", "equals", value: "alice@example.com")],
          },
          { "json" => { "input_marker" => "keep-me" } },
        )

      expect(items.length).to eq(1)
      expect(items.first["json"]).to eq("input_marker" => "keep-me")
      expect(items.first["json"]).not_to have_key("email")
      expect(items.first["pairedItem"]).to eq("item" => 0)
    end

    it "drops the input item when no row matches" do
      items =
        execute_data_table_with_item(
          {
            "operation" => "row_exists",
            "data_table_id" => data_table.id.to_s,
            "filter" => [filter_condition("email", "equals", value: "missing@test.com")],
          },
          { "json" => { "input_marker" => "drop-me" } },
        )

      expect(items).to eq([])
    end

    it "raises when the filter is missing" do
      expect {
        execute_data_table("operation" => "row_exists", "data_table_id" => data_table.id.to_s)
      }.to raise_error(DiscourseWorkflows::NodeError, /Filter must not be empty/)
    end

    it "raises when the filter is an empty array" do
      expect {
        execute_data_table(
          "operation" => "row_exists",
          "data_table_id" => data_table.id.to_s,
          "filter" => [],
        )
      }.to raise_error(DiscourseWorkflows::NodeError, /Filter must not be empty/)
    end
  end

  describe "row_not_exists operation" do
    before { insert_data_table_row(data_table, "email" => "alice@example.com", "score" => 10) }

    it "emits the input item unchanged when no row matches" do
      items =
        execute_data_table_with_item(
          {
            "operation" => "row_not_exists",
            "data_table_id" => data_table.id.to_s,
            "filter" => [filter_condition("email", "equals", value: "missing@test.com")],
          },
          { "json" => { "input_marker" => "keep-me" } },
        )

      expect(items.length).to eq(1)
      expect(items.first["json"]).to eq("input_marker" => "keep-me")
      expect(items.first["pairedItem"]).to eq("item" => 0)
    end

    it "drops the input item when at least one row matches" do
      items =
        execute_data_table_with_item(
          {
            "operation" => "row_not_exists",
            "data_table_id" => data_table.id.to_s,
            "filter" => [filter_condition("email", "equals", value: "alice@example.com")],
          },
          { "json" => { "input_marker" => "drop-me" } },
        )

      expect(items).to eq([])
    end

    it "raises when the filter is missing" do
      expect {
        execute_data_table("operation" => "row_not_exists", "data_table_id" => data_table.id.to_s)
      }.to raise_error(DiscourseWorkflows::NodeError, /Filter must not be empty/)
    end
  end

  describe "upsert operation" do
    it "requires a filter" do
      insert_data_table_row(data_table, "email" => "existing@test.com", "score" => 1)

      expect {
        execute_data_table(
          "operation" => "upsert",
          "data_table_id" => data_table.id.to_s,
          "columns" => {
            "email" => "nf@test.com",
            "score" => "10",
          },
        )
      }.to raise_error(DiscourseWorkflows::NodeError, /Filter must not be empty/)
    end

    it "inserts when the filter does not match a row" do
      insert_data_table_row(data_table, "email" => "existing@test.com", "score" => 1)

      items =
        execute_data_table(
          "operation" => "upsert",
          "data_table_id" => data_table.id.to_s,
          "filter" => [filter_condition("email", "equals", value: "nf@test.com")],
          "columns" => {
            "email" => "nf@test.com",
            "score" => "10",
          },
        )

      expect(items.map { |item| item["json"].slice("email", "score") }).to eq(
        [{ "email" => "nf@test.com", "score" => 10 }],
      )
      expect(count_data_table_rows(data_table)).to eq(2)
    end

    it "updates when the filter matches an existing row" do
      insert_data_table_row(data_table, "email" => "existing@test.com", "score" => 1)

      items =
        execute_data_table(
          "operation" => "upsert",
          "data_table_id" => data_table.id.to_s,
          "filter" => [filter_condition("email", "equals", value: "existing@test.com")],
          "columns" => {
            "score" => "10",
          },
        )

      expect(items.map { |item| item["json"].slice("email", "score") }).to eq(
        [{ "email" => "existing@test.com", "score" => 10 }],
      )
      expect(count_data_table_rows(data_table)).to eq(1)
    end

    it "raises when the storage limit is exceeded" do
      allow(DiscourseWorkflows::DataTables::Facade).to receive(:within_storage_limit?).and_return(
        false,
      )

      expect {
        execute_data_table(
          "operation" => "upsert",
          "data_table_id" => data_table.id.to_s,
          "filter" => [filter_condition("email", "equals", value: "new@test.com")],
          "columns" => {
            "email" => "new@test.com",
            "score" => "50",
          },
        )
      }.to raise_error(DiscourseWorkflows::NodeError, "Data table storage limit exceeded")
    end
  end
end
