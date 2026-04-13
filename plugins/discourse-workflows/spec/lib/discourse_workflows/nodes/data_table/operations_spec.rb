# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::DataTable::Operations do
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

  let(:facade) { DiscourseWorkflows::DataTables::Facade.new(data_table) }
  let(:columns_resolver) { DiscourseWorkflows::Nodes::DataTable::ColumnsResolver.new(data_table) }

  def build_operation(name)
    described_class.for(name).new(facade, columns_resolver, data_table)
  end

  describe ".for" do
    it "raises for unknown operations" do
      expect { described_class.for("truncate") }.to raise_error(ArgumentError, /Unknown operation/)
    end
  end

  describe "Insert" do
    it "inserts a row and returns it as an item" do
      items =
        build_operation("insert").execute("columns" => { "email" => "a@test.com", "score" => "10" })

      expect(items.length).to eq(1)
      expect(items.first["json"]).to include("email" => "a@test.com", "score" => 10)
      expect(count_data_table_rows(data_table)).to eq(1)
    end
  end

  describe "Get" do
    before do
      insert_data_table_row(data_table, "email" => "a@test.com", "score" => 10)
      insert_data_table_row(data_table, "email" => "b@test.com", "score" => 20)
    end

    it "returns all rows without filter" do
      items = build_operation("get").execute("data_table_id" => data_table.id.to_s)

      expect(items.length).to eq(2)
    end

    it "filters rows" do
      items =
        build_operation("get").execute(
          "filter_combinator" => "and",
          "filter" => [{ "columnName" => "score", "condition" => "gt", "value" => "15" }],
        )

      expect(items.length).to eq(1)
      expect(items.first["json"]["email"]).to eq("b@test.com")
    end
  end

  describe "Update" do
    before { insert_data_table_row(data_table, "email" => "up@test.com", "score" => 1) }

    it "updates matching rows and returns count" do
      items =
        build_operation("update").execute(
          "filter" => [{ "columnName" => "email", "condition" => "equals", "value" => "up@test.com" }],
          "columns" => {
            "score" => "99",
          },
        )

      expect(items.first["json"]["updated_count"]).to eq(1)
    end
  end

  describe "Delete" do
    before { insert_data_table_row(data_table, "email" => "del@test.com", "score" => 5) }

    it "deletes matching rows and returns count" do
      items =
        build_operation("delete").execute(
          "filter" => [
            { "columnName" => "email", "condition" => "equals", "value" => "del@test.com" },
          ],
        )

      expect(items.first["json"]["deleted_count"]).to eq(1)
      expect(count_data_table_rows(data_table)).to eq(0)
    end
  end

  describe "Upsert" do
    it "inserts when no filter is provided" do
      items =
        build_operation("upsert").execute(
          "columns" => {
            "email" => "new@test.com",
            "score" => "10",
          },
        )

      expect(items.first["json"]["operation"]).to eq("insert")
      expect(count_data_table_rows(data_table)).to eq(1)
    end

    it "inserts when no match exists" do
      items =
        build_operation("upsert").execute(
          "filter" => [
            { "columnName" => "email", "condition" => "equals", "value" => "new@test.com" },
          ],
          "columns" => {
            "email" => "new@test.com",
            "score" => "50",
          },
        )

      expect(items.first["json"]["operation"]).to eq("insert")
    end

    it "updates when match exists" do
      insert_data_table_row(data_table, "email" => "exists@test.com", "score" => 10)

      items =
        build_operation("upsert").execute(
          "filter" => [
            { "columnName" => "email", "condition" => "equals", "value" => "exists@test.com" },
          ],
          "columns" => {
            "score" => "99",
          },
        )

      expect(items.first["json"]["operation"]).to eq("update")
      expect(items.first["json"]["count"]).to eq(1)
    end
  end
end
