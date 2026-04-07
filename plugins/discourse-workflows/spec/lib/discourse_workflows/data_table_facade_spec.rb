# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTableFacade do
  fab!(:data_table) do
    Fabricate(
      :discourse_workflows_data_table,
      columns: [
        { "name" => "email", "type" => "string" },
        { "name" => "score", "type" => "number" },
        { "name" => "active", "type" => "boolean" },
        { "name" => "joined_at", "type" => "date" },
      ],
    )
  end

  let(:facade) { described_class.new(data_table) }

  let!(:row_1) do
    insert_data_table_row(
      data_table,
      {
        "email" => "alice@example.com",
        "score" => 90,
        "active" => true,
        "joined_at" => "2024-01-10",
      },
    )
  end

  let!(:row_2) do
    insert_data_table_row(
      data_table,
      {
        "email" => "bob@example.com",
        "score" => 60,
        "active" => false,
        "joined_at" => "2024-01-11",
      },
    )
  end

  let!(:row_3) do
    insert_data_table_row(
      data_table,
      { "email" => "carol_data@example.com", "score" => nil, "active" => nil },
    )
  end

  def build_query(
    filter: nil,
    limit: nil,
    offset: nil,
    sort_by: nil,
    sort_direction: nil,
    optional_filter: true
  )
    facade.build_query(
      filter: filter,
      limit: limit,
      offset: offset,
      sort_by: sort_by,
      sort_direction: sort_direction,
      optional_filter: optional_filter,
    )
  end

  def build_row_input(data, fill_missing: false)
    facade.build_row_input(data: data, fill_missing: fill_missing)
  end

  describe "#build_query" do
    it "returns an invalid query when the filter is invalid" do
      query =
        build_query(
          filter: {
            "type" => "and",
            "filters" => [{ "columnName" => "missing", "condition" => "eq", "value" => "x" }],
          },
        )

      expect(query).to be_invalid
      expect(query.errors.full_messages).to include("Unknown column name 'missing'")
    end
  end

  describe "#query" do
    it "returns all rows without a filter" do
      result = facade.query(build_query)

      expect(result[:count]).to eq(3)
      expect(result[:rows].map { |row| row["id"] }).to eq([row_1["id"], row_2["id"], row_3["id"]])
    end

    it "supports filtering" do
      result =
        facade.query(
          build_query(
            filter: {
              "type" => "and",
              "filters" => [
                { "columnName" => "email", "condition" => "ilike", "value" => "ALICE" },
              ],
            },
          ),
        )

      expect(result[:rows].map { |row| row["id"] }).to eq([row_1["id"]])
    end

    it "sorts and limits deterministically" do
      result = facade.query(build_query(sort_by: "score", sort_direction: "desc", limit: 2))

      expect(result[:rows].map { |row| row["id"] }).to eq([row_1["id"], row_2["id"]])
    end

    it "supports pagination with offset" do
      result = facade.query(build_query(limit: 1, offset: 1))

      expect(result[:count]).to eq(3)
      expect(result[:rows].size).to eq(1)
      expect(result[:rows].first["id"]).to eq(row_2["id"])
    end
  end

  describe "#find_row" do
    it "returns a row by id" do
      row = facade.find_row(row_1["id"])

      expect(row["email"]).to eq("alice@example.com")
      expect(row["score"]).to eq(90)
    end

    it "returns nil for a non-existent id" do
      expect(facade.find_row(-1)).to be_nil
    end
  end

  describe "#count" do
    it "returns the total count without a filter" do
      expect(facade.count).to eq(3)
    end
  end

  describe "#insert" do
    it "inserts a row with cast data" do
      row = facade.insert(build_row_input({ "email" => "test@test.com" }, fill_missing: true))

      expect(row["email"]).to eq("test@test.com")
      expect(row["score"]).to be_nil
    end

    it "inserts a default row when data is empty" do
      row = facade.insert(build_row_input({}))

      expect(row["id"]).to be_present
    end
  end

  describe "#update_row" do
    it "updates a single row and returns it" do
      updated =
        facade.update_row(row_id: row_1["id"], row_input: build_row_input({ "score" => 99 }))

      expect(updated["score"]).to eq(99)
      expect(updated["email"]).to eq("alice@example.com")
    end

    it "returns nil for a non-existent id" do
      updated = facade.update_row(row_id: -1, row_input: build_row_input({ "score" => 99 }))

      expect(updated).to be_nil
    end

    it "returns nil when the row input is empty" do
      expect(facade.update_row(row_id: row_1["id"], row_input: build_row_input({}))).to be_nil
    end
  end

  describe "#update" do
    it "updates matching rows and returns the affected count" do
      updated_count =
        facade.update(
          query:
            build_query(
              filter: {
                "type" => "and",
                "filters" => [
                  { "columnName" => "email", "condition" => "eq", "value" => "alice@example.com" },
                ],
              },
            ),
          row_input: build_row_input({ "score" => 99 }),
        )

      expect(updated_count).to eq(1)
      expect(find_data_table_row(data_table, row_1["id"])["score"]).to eq(99)
    end
  end

  describe "#delete_row" do
    it "deletes a row and returns true" do
      expect(facade.delete_row(row_1["id"])).to be(true)
      expect(find_data_table_row(data_table, row_1["id"])).to be_nil
    end

    it "returns false for a non-existent id" do
      expect(facade.delete_row(-1)).to be(false)
    end
  end

  describe "#delete" do
    it "deletes matching rows and returns the affected count" do
      deleted_count =
        facade.delete(
          query:
            build_query(
              filter: {
                "type" => "and",
                "filters" => [
                  { "columnName" => "email", "condition" => "eq", "value" => "bob@example.com" },
                ],
              },
            ),
        )

      expect(deleted_count).to eq(1)
      expect(find_data_table_row(data_table, row_2["id"])).to be_nil
    end
  end

  describe "#upsert" do
    it "updates matching rows when they exist" do
      result =
        facade.upsert(
          query:
            build_query(
              filter: {
                "type" => "and",
                "filters" => [
                  { "columnName" => "email", "condition" => "eq", "value" => "alice@example.com" },
                ],
              },
            ),
          row_input: build_row_input({ "score" => 100 }),
        )

      expect(result).to eq(operation: "update", updated_count: 1)
      expect(find_data_table_row(data_table, row_1["id"])["score"]).to eq(100)
    end

    it "inserts a new row when there is no match" do
      result =
        facade.upsert(
          query:
            build_query(
              filter: {
                "type" => "and",
                "filters" => [
                  { "columnName" => "email", "condition" => "eq", "value" => "new@example.com" },
                ],
              },
            ),
          row_input: build_row_input({ "email" => "new@example.com", "score" => 42 }),
        )

      expect(result[:operation]).to eq("insert")
      expect(result[:row]["email"]).to eq("new@example.com")
    end
  end

  describe "#add_column!" do
    it "adds a column to the storage table" do
      facade.add_column!("notes", "string")

      reloaded_facade = described_class.new(data_table)
      row = reloaded_facade.insert(reloaded_facade.build_row_input(data: { "notes" => "hello" }))
      expect(row["notes"]).to eq("hello")
    end
  end

  describe "#rename_column!" do
    it "renames a column in the storage table" do
      facade.rename_column!(old_name: "email", new_name: "contact_email")

      table_name = DiscourseWorkflows::DataTableStorage.table_name(data_table.id)
      columns =
        DB.query_single(
          "SELECT column_name FROM information_schema.columns WHERE table_name = :table_name",
          table_name: table_name,
        )

      expect(columns).to include("contact_email")
      expect(columns).not_to include("email")
    end
  end

  describe "#drop_column!" do
    it "drops a column from the storage table" do
      facade.drop_column!("active")

      table_name = DiscourseWorkflows::DataTableStorage.table_name(data_table.id)
      columns =
        DB.query_single(
          "SELECT column_name FROM information_schema.columns WHERE table_name = :table_name",
          table_name: table_name,
        )

      expect(columns).not_to include("active")
    end
  end

  describe ".within_storage_limit?" do
    it "returns true when under the limit" do
      expect(described_class.within_storage_limit?).to be(true)
    end
  end

  describe ".reset_storage_cache!" do
    it "delegates to the size validator" do
      allow(DiscourseWorkflows::DataTableSizeValidator).to receive(:reset!)

      described_class.reset_storage_cache!

      expect(DiscourseWorkflows::DataTableSizeValidator).to have_received(:reset!)
    end
  end

  describe ".total_size_bytes" do
    it "returns the total size across all data tables" do
      expect(described_class.total_size_bytes).to be_a(Integer)
    end
  end

  describe ".batch_size_bytes" do
    it "returns sizes keyed by data table id" do
      sizes = described_class.batch_size_bytes([data_table.id])

      expect(sizes).to have_key(data_table.id)
      expect(sizes[data_table.id]).to be_a(Integer)
    end
  end

  describe ".count_for" do
    it "returns the count for a data table" do
      expect(described_class.count_for(data_table)).to eq(3)
    end
  end
end
