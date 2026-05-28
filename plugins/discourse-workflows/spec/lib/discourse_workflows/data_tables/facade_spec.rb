# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTables::Facade do
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

  let!(:row_4) do
    insert_data_table_row(
      data_table,
      { "email" => "50%off@example.com", "score" => 50, "active" => true },
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

      expect(result[:count]).to eq(4)
      expect(result[:rows].map { |row| row["id"] }).to eq(
        [row_1["id"], row_2["id"], row_3["id"], row_4["id"]],
      )
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

      expect(result[:count]).to eq(4)
      expect(result[:rows].size).to eq(1)
      expect(result[:rows].first["id"]).to eq(row_2["id"])
    end
  end

  describe "filtering" do
    describe "eq condition" do
      it "matches exact values" do
        result =
          facade.query(
            build_query(
              filter: {
                "type" => "and",
                "filters" => [{ "columnName" => "score", "condition" => "eq", "value" => 90 }],
              },
            ),
          )

        expect(result[:rows].map { |r| r["id"] }).to eq([row_1["id"]])
      end

      it "matches nil values" do
        result =
          facade.query(
            build_query(
              filter: {
                "type" => "and",
                "filters" => [{ "columnName" => "score", "condition" => "eq", "value" => nil }],
              },
            ),
          )

        expect(result[:rows].map { |r| r["id"] }).to eq([row_3["id"]])
      end
    end

    describe "neq condition" do
      it "excludes matching values and includes nulls" do
        result =
          facade.query(
            build_query(
              filter: {
                "type" => "and",
                "filters" => [{ "columnName" => "score", "condition" => "neq", "value" => 90 }],
              },
            ),
          )

        expect(result[:rows].map { |r| r["id"] }).to contain_exactly(
          row_2["id"],
          row_3["id"],
          row_4["id"],
        )
      end

      it "excludes nil values" do
        result =
          facade.query(
            build_query(
              filter: {
                "type" => "and",
                "filters" => [{ "columnName" => "score", "condition" => "neq", "value" => nil }],
              },
            ),
          )

        expect(result[:rows].map { |r| r["id"] }).to contain_exactly(
          row_1["id"],
          row_2["id"],
          row_4["id"],
        )
      end
    end

    describe "comparison conditions" do
      it "gt filters strictly greater" do
        result =
          facade.query(
            build_query(
              filter: {
                "type" => "and",
                "filters" => [{ "columnName" => "score", "condition" => "gt", "value" => 60 }],
              },
            ),
          )

        expect(result[:rows].map { |r| r["id"] }).to eq([row_1["id"]])
      end

      it "gte includes equal values" do
        result =
          facade.query(
            build_query(
              filter: {
                "type" => "and",
                "filters" => [{ "columnName" => "score", "condition" => "gte", "value" => 60 }],
              },
            ),
          )

        expect(result[:rows].map { |r| r["id"] }).to contain_exactly(row_1["id"], row_2["id"])
      end

      it "lt filters strictly less" do
        result =
          facade.query(
            build_query(
              filter: {
                "type" => "and",
                "filters" => [{ "columnName" => "score", "condition" => "lt", "value" => 90 }],
              },
            ),
          )

        expect(result[:rows].map { |r| r["id"] }).to contain_exactly(row_2["id"], row_4["id"])
      end

      it "lte includes equal values" do
        result =
          facade.query(
            build_query(
              filter: {
                "type" => "and",
                "filters" => [{ "columnName" => "score", "condition" => "lte", "value" => 60 }],
              },
            ),
          )

        expect(result[:rows].map { |r| r["id"] }).to contain_exactly(row_2["id"], row_4["id"])
      end
    end

    describe "like conditions" do
      it "case-sensitive like match" do
        result =
          facade.query(
            build_query(
              filter: {
                "type" => "and",
                "filters" => [
                  { "columnName" => "email", "condition" => "like", "value" => "alice" },
                ],
              },
            ),
          )

        expect(result[:rows].map { |r| r["id"] }).to eq([row_1["id"]])
      end

      it "case-insensitive ilike match" do
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

        expect(result[:rows].map { |r| r["id"] }).to eq([row_1["id"]])
      end

      it "not_ilike excludes matches" do
        result =
          facade.query(
            build_query(
              filter: {
                "type" => "and",
                "filters" => [
                  { "columnName" => "email", "condition" => "not_ilike", "value" => "alice" },
                ],
              },
            ),
          )

        expect(result[:rows].map { |r| r["id"] }).not_to include(row_1["id"])
      end

      it "escapes underscore in like patterns" do
        result =
          facade.query(
            build_query(
              filter: {
                "type" => "and",
                "filters" => [
                  { "columnName" => "email", "condition" => "ilike", "value" => "a_ice" },
                ],
              },
            ),
          )

        expect(result[:rows]).to be_empty
      end

      it "escapes percent in like patterns" do
        result =
          facade.query(
            build_query(
              filter: {
                "type" => "and",
                "filters" => [
                  { "columnName" => "email", "condition" => "ilike", "value" => "50%off" },
                ],
              },
            ),
          )

        expect(result[:rows].map { |r| r["id"] }).to eq([row_4["id"]])
      end
    end

    describe "AND/OR combination" do
      it "AND requires all conditions to match" do
        result =
          facade.query(
            build_query(
              filter: {
                "type" => "and",
                "filters" => [
                  { "columnName" => "score", "condition" => "eq", "value" => 60 },
                  { "columnName" => "active", "condition" => "eq", "value" => false },
                ],
              },
            ),
          )

        expect(result[:rows].map { |r| r["id"] }).to eq([row_2["id"]])
      end

      it "OR requires any condition to match" do
        result =
          facade.query(
            build_query(
              filter: {
                "type" => "or",
                "filters" => [
                  { "columnName" => "score", "condition" => "eq", "value" => 90 },
                  { "columnName" => "active", "condition" => "eq", "value" => false },
                ],
              },
            ),
          )

        expect(result[:rows].map { |r| r["id"] }).to contain_exactly(row_1["id"], row_2["id"])
      end
    end
  end

  describe "ordering" do
    it "defaults to id ascending when sort_by is blank" do
      result = facade.query(build_query)

      expect(result[:rows].map { |r| r["id"] }).to eq(
        [row_1["id"], row_2["id"], row_3["id"], row_4["id"]],
      )
    end

    it "sorts ascending with nulls last" do
      result = facade.query(build_query(sort_by: "score", sort_direction: "asc"))
      ids = result[:rows].map { |r| r["id"] }

      expect(ids).to eq([row_4["id"], row_2["id"], row_1["id"], row_3["id"]])
    end

    it "sorts descending with nulls last" do
      result = facade.query(build_query(sort_by: "score", sort_direction: "desc"))
      ids = result[:rows].map { |r| r["id"] }

      expect(ids.first).to eq(row_1["id"])
      expect(ids.last).to eq(row_3["id"])
    end

    it "defaults to ASC for invalid direction" do
      result = facade.query(build_query(sort_by: "score", sort_direction: "invalid"))
      ids = result[:rows].map { |r| r["id"] }

      expect(ids).to eq([row_4["id"], row_2["id"], row_1["id"], row_3["id"]])
    end

    it "uses id as secondary sort for stability" do
      row_4 =
        insert_data_table_row(
          data_table,
          { "email" => "dave@example.com", "score" => 60, "active" => true },
        )

      result = facade.query(build_query(sort_by: "score", sort_direction: "asc"))
      ids = result[:rows].map { |r| r["id"] }
      bob_idx = ids.index(row_2["id"])
      dave_idx = ids.index(row_4["id"])

      expect(bob_idx).to be < dave_idx
    end

    it "raises ArgumentError for unknown sort column" do
      expect { facade.query(build_query(sort_by: "'; DROP TABLE users; --")) }.to raise_error(
        ArgumentError,
        /Invalid sort column/,
      )
    end
  end

  describe "pagination" do
    it "limits results" do
      result = facade.query(build_query(limit: 2))

      expect(result[:rows].size).to eq(2)
    end

    it "offsets results" do
      all_ids = facade.query(build_query)[:rows].map { |r| r["id"] }

      result = facade.query(build_query(offset: 2))

      expect(result[:rows].map { |r| r["id"] }).to eq(all_ids[2..])
    end

    it "combines limit and offset" do
      all_ids = facade.query(build_query)[:rows].map { |r| r["id"] }

      result = facade.query(build_query(limit: 1, offset: 1))

      expect(result[:rows].map { |r| r["id"] }).to eq([all_ids[1]])
    end

    it "caps limit at MAX_LIMIT" do
      result = facade.query(build_query(limit: 999))

      expect(result[:rows].size).to be <= described_class::MAX_LIMIT
    end

    it "ignores zero limit" do
      result = facade.query(build_query(limit: 0))

      expect(result[:rows].size).to eq(4)
    end

    it "ignores zero offset" do
      all_ids = facade.query(build_query)[:rows].map { |r| r["id"] }

      result = facade.query(build_query(offset: 0))

      expect(result[:rows].map { |r| r["id"] }).to eq(all_ids)
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
      expect(facade.count).to eq(4)
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

  describe "#delete_rows" do
    it "deletes rows by ids and returns the affected count" do
      expect(facade.delete_rows([row_1["id"]])).to eq(1)
      expect(find_data_table_row(data_table, row_1["id"])).to be_nil
    end

    it "returns 0 for non-existent ids" do
      expect(facade.delete_rows([-1])).to eq(0)
    end

    it "returns 0 for an empty array" do
      expect(facade.delete_rows([])).to eq(0)
    end

    it "deletes rows when storage is over the limit" do
      allow(described_class).to receive(:within_storage_limit?).and_return(false)

      expect(facade.delete_rows([row_1["id"]])).to eq(1)
      expect(find_data_table_row(data_table, row_1["id"])).to be_nil
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

    it "deletes matching rows when storage is over the limit" do
      allow(described_class).to receive(:within_storage_limit?).and_return(false)

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

  describe "statement timeout" do
    it "raises StatementTimeout when a query exceeds the limit" do
      stub_const(DiscourseWorkflows::DataTables::Facade, :STATEMENT_TIMEOUT_MS, 100) do
        expect {
          facade.send(:with_statement_timeout) do
            ActiveRecord::Base.connection.execute("SELECT pg_sleep(1)")
          end
        }.to raise_error(described_class::StatementTimeout)
      end
    end
  end

  describe "lock timeout" do
    it "wraps the block in a transaction so SET LOCAL lock_timeout takes effect" do
      initial_open_transactions = ActiveRecord::Base.connection.open_transactions
      observed_open_transactions = nil

      facade.send(:with_lock_timeout) do
        observed_open_transactions = ActiveRecord::Base.connection.open_transactions
      end

      expect(observed_open_transactions).to eq(initial_open_transactions + 1)
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

      table_name = DiscourseWorkflows::DataTables::Storage.table_name(data_table.id)
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

      table_name = DiscourseWorkflows::DataTables::Storage.table_name(data_table.id)
      columns =
        DB.query_single(
          "SELECT column_name FROM information_schema.columns WHERE table_name = :table_name",
          table_name: table_name,
        )

      expect(columns).not_to include("active")
    end
  end
end
