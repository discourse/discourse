# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTableQueryBuilder do
  fab!(:data_table) do
    Fabricate(
      :discourse_workflows_data_table,
      columns: [
        { "name" => "email", "type" => "string" },
        { "name" => "score", "type" => "number" },
        { "name" => "active", "type" => "boolean" },
      ],
    )
  end

  let(:table_name) { DiscourseWorkflows::DataTableStorage.table_name(data_table.id) }
  let(:table) { Arel::Table.new(table_name) }
  let(:builder) { described_class.new(table) }

  let!(:row_alice) do
    insert_data_table_row(
      data_table,
      { "email" => "alice@ex.com", "score" => 90, "active" => true },
    )
  end
  let!(:row_bob) do
    insert_data_table_row(data_table, { "email" => "bob@ex.com", "score" => 60, "active" => false })
  end
  let!(:row_carol) do
    insert_data_table_row(
      data_table,
      { "email" => "carol@ex.com", "score" => 60, "active" => true },
    )
  end
  let!(:row_nil) { insert_data_table_row(data_table, { "email" => "nil@ex.com" }) }

  def query_ids(arel_query)
    ActiveRecord::Base.connection.exec_query(arel_query.to_sql).to_a.map { |r| r["id"] }
  end

  def base_query
    table.project(table[:id])
  end

  describe "#apply_filters" do
    it "returns query unchanged when filter is nil" do
      result = builder.apply_filters(base_query, nil)
      expect(query_ids(result)).to contain_exactly(
        row_alice["id"],
        row_bob["id"],
        row_carol["id"],
        row_nil["id"],
      )
    end

    it "returns query unchanged when filter has no filters array" do
      result = builder.apply_filters(base_query, { "type" => "and", "filters" => [] })
      expect(query_ids(result)).to contain_exactly(
        row_alice["id"],
        row_bob["id"],
        row_carol["id"],
        row_nil["id"],
      )
    end

    describe "eq condition" do
      it "matches exact values" do
        filter = {
          "type" => "and",
          "filters" => [{ "columnName" => "score", "condition" => "eq", "value" => 90 }],
        }
        expect(query_ids(builder.apply_filters(base_query, filter))).to eq([row_alice["id"]])
      end

      it "matches nil values" do
        filter = {
          "type" => "and",
          "filters" => [{ "columnName" => "score", "condition" => "eq", "value" => nil }],
        }
        expect(query_ids(builder.apply_filters(base_query, filter))).to eq([row_nil["id"]])
      end
    end

    describe "neq condition" do
      it "excludes matching values and includes nulls" do
        filter = {
          "type" => "and",
          "filters" => [{ "columnName" => "score", "condition" => "neq", "value" => 90 }],
        }
        ids = query_ids(builder.apply_filters(base_query, filter))
        expect(ids).to contain_exactly(row_bob["id"], row_carol["id"], row_nil["id"])
      end

      it "excludes nil values" do
        filter = {
          "type" => "and",
          "filters" => [{ "columnName" => "score", "condition" => "neq", "value" => nil }],
        }
        ids = query_ids(builder.apply_filters(base_query, filter))
        expect(ids).to contain_exactly(row_alice["id"], row_bob["id"], row_carol["id"])
      end
    end

    describe "comparison conditions" do
      it "gt filters strictly greater" do
        filter = {
          "type" => "and",
          "filters" => [{ "columnName" => "score", "condition" => "gt", "value" => 60 }],
        }
        expect(query_ids(builder.apply_filters(base_query, filter))).to eq([row_alice["id"]])
      end

      it "gte includes equal values" do
        filter = {
          "type" => "and",
          "filters" => [{ "columnName" => "score", "condition" => "gte", "value" => 60 }],
        }
        ids = query_ids(builder.apply_filters(base_query, filter))
        expect(ids).to contain_exactly(row_alice["id"], row_bob["id"], row_carol["id"])
      end

      it "lt filters strictly less" do
        filter = {
          "type" => "and",
          "filters" => [{ "columnName" => "score", "condition" => "lt", "value" => 90 }],
        }
        ids = query_ids(builder.apply_filters(base_query, filter))
        expect(ids).to contain_exactly(row_bob["id"], row_carol["id"])
      end

      it "lte includes equal values" do
        filter = {
          "type" => "and",
          "filters" => [{ "columnName" => "score", "condition" => "lte", "value" => 60 }],
        }
        ids = query_ids(builder.apply_filters(base_query, filter))
        expect(ids).to contain_exactly(row_bob["id"], row_carol["id"])
      end
    end

    describe "like conditions" do
      it "case-sensitive like match" do
        filter = {
          "type" => "and",
          "filters" => [{ "columnName" => "email", "condition" => "like", "value" => "%alice%" }],
        }
        expect(query_ids(builder.apply_filters(base_query, filter))).to eq([row_alice["id"]])
      end

      it "case-insensitive ilike match" do
        filter = {
          "type" => "and",
          "filters" => [{ "columnName" => "email", "condition" => "ilike", "value" => "%ALICE%" }],
        }
        expect(query_ids(builder.apply_filters(base_query, filter))).to eq([row_alice["id"]])
      end

      it "not_ilike excludes matches" do
        filter = {
          "type" => "and",
          "filters" => [
            { "columnName" => "email", "condition" => "not_ilike", "value" => "%alice%" },
          ],
        }
        ids = query_ids(builder.apply_filters(base_query, filter))
        expect(ids).not_to include(row_alice["id"])
      end

      it "escapes underscore in like patterns" do
        filter = {
          "type" => "and",
          "filters" => [{ "columnName" => "email", "condition" => "ilike", "value" => "%a_ice%" }],
        }
        expect(query_ids(builder.apply_filters(base_query, filter))).to be_empty
      end
    end

    describe "AND/OR combination" do
      it "AND requires all conditions to match" do
        filter = {
          "type" => "and",
          "filters" => [
            { "columnName" => "score", "condition" => "eq", "value" => 60 },
            { "columnName" => "active", "condition" => "eq", "value" => false },
          ],
        }
        expect(query_ids(builder.apply_filters(base_query, filter))).to eq([row_bob["id"]])
      end

      it "OR requires any condition to match" do
        filter = {
          "type" => "or",
          "filters" => [
            { "columnName" => "score", "condition" => "eq", "value" => 90 },
            { "columnName" => "active", "condition" => "eq", "value" => false },
          ],
        }
        ids = query_ids(builder.apply_filters(base_query, filter))
        expect(ids).to contain_exactly(row_alice["id"], row_bob["id"])
      end
    end
  end

  describe "#apply_ordering" do
    it "defaults to id ascending when sort_by is blank" do
      result = builder.apply_ordering(base_query, nil, nil)
      expect(query_ids(result)).to eq(
        [row_alice["id"], row_bob["id"], row_carol["id"], row_nil["id"]],
      )
    end

    it "sorts ascending" do
      result = builder.apply_ordering(base_query, "score", "asc")
      ids = query_ids(result)
      expect(ids.first(3)).to eq([row_bob["id"], row_carol["id"], row_alice["id"]])
      expect(ids.last).to eq(row_nil["id"])
    end

    it "sorts descending with nulls last" do
      result = builder.apply_ordering(base_query, "score", "desc")
      ids = query_ids(result)
      expect(ids.first).to eq(row_alice["id"])
      expect(ids.last).to eq(row_nil["id"])
    end

    it "defaults to ASC for invalid direction" do
      result = builder.apply_ordering(base_query, "score", "invalid")
      ids = query_ids(result)
      expect(ids.first(3)).to eq([row_bob["id"], row_carol["id"], row_alice["id"]])
    end

    it "uses id as secondary sort for stability" do
      result = builder.apply_ordering(base_query, "score", "asc")
      ids = query_ids(result)
      bob_idx = ids.index(row_bob["id"])
      carol_idx = ids.index(row_carol["id"])
      expect(bob_idx).to be < carol_idx
    end
  end

  describe "#apply_pagination" do
    it "limits results" do
      result = builder.apply_pagination(base_query.order(table[:id].asc), 2, nil)
      expect(query_ids(result).size).to eq(2)
    end

    it "offsets results" do
      ordered = base_query.order(table[:id].asc)
      all_ids = query_ids(ordered)
      result = builder.apply_pagination(ordered, nil, 2)
      expect(query_ids(result)).to eq(all_ids[2..])
    end

    it "combines limit and offset" do
      ordered = base_query.order(table[:id].asc)
      all_ids = query_ids(ordered)
      result = builder.apply_pagination(ordered, 1, 1)
      expect(query_ids(result)).to eq([all_ids[1]])
    end

    it "caps limit at MAX_LIMIT" do
      result = builder.apply_pagination(base_query, 999, nil)
      expect(query_ids(result).size).to be <= described_class::MAX_LIMIT
    end

    it "ignores zero limit" do
      result = builder.apply_pagination(base_query, 0, nil)
      expect(query_ids(result).size).to eq(4)
    end

    it "ignores zero offset" do
      ordered = base_query.order(table[:id].asc)
      all_ids = query_ids(ordered)
      result = builder.apply_pagination(ordered, nil, 0)
      expect(query_ids(result)).to eq(all_ids)
    end
  end
end
