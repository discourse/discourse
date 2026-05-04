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

  def execute_data_table_with_item(configuration, item)
    execute_node_result(configuration: configuration, item: item).primary_items(
      ports: described_class.ports,
    )
  end

  describe ".load_options" do
    it "marks reserved columns" do
      tables = described_class.load_options("data_tables")
      table_meta = tables.find { |dt| dt[:id] == data_table.id }
      column_names_reserved = table_meta[:columns].select { |c| c[:reserved] }.map { |c| c[:name] }

      expect(column_names_reserved).to contain_exactly("id", "created_at", "updated_at")
      expect(table_meta[:columns].find { |c| c[:name] == "email" }).not_to have_key(:reserved)
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
      }.to raise_error(ArgumentError, /Unknown column name/)
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
      }.to raise_error(ArgumentError, "Data table storage limit exceeded")
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
    end
  end

  describe "update operation" do
    fab!(:row) { insert_data_table_row(data_table, "email" => "up@test.com", "score" => 1) }

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
      allow(DiscourseWorkflows::DataTables::Facade).to receive(:within_storage_limit?).and_return(
        false,
      )

      expect {
        execute_data_table(
          "operation" => "update",
          "data_table_id" => data_table.id.to_s,
          "filter" => [
            { "columnName" => "email", "condition" => "equals", "value" => "up@test.com" },
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

    it "raises when the storage limit is exceeded" do
      allow(DiscourseWorkflows::DataTables::Facade).to receive(:within_storage_limit?).and_return(
        false,
      )

      expect {
        execute_data_table(
          "operation" => "upsert",
          "data_table_id" => data_table.id.to_s,
          "filter" => [
            { "columnName" => "email", "condition" => "equals", "value" => "new@test.com" },
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
