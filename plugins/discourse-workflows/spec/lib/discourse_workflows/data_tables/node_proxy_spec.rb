# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTables::NodeProxy do
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

  subject(:proxy) { described_class.new(data_table_facade(data_table)) }

  def email_filter(email)
    {
      "type" => "and",
      "filters" => [{ "columnName" => "email", "condition" => "eq", "value" => email }],
    }
  end

  it "returns user columns without system columns" do
    expect(proxy.get_columns).to eq(
      [
        { id: "email", name: "email", type: "string", index: 0, data_table_id: data_table.id },
        { id: "score", name: "score", type: "number", index: 1, data_table_id: data_table.id },
      ],
    )
  end

  it "inserts rows with return mode 'all'" do
    rows = [
      { "email" => "a@example.com", "score" => "1" },
      { "email" => "b@example.com", "score" => "2" },
    ]

    inserted_rows = proxy.insert_rows(rows, "all")
    expect(inserted_rows.map { |row| row.slice("email", "score") }).to eq(
      [{ "email" => "a@example.com", "score" => 1 }, { "email" => "b@example.com", "score" => 2 }],
    )

    ids = proxy.insert_rows([{ "email" => "c@example.com" }], "id")
    expect(ids.first.keys).to contain_exactly("id")

    expect(proxy.insert_rows([{ "email" => "d@example.com" }], "count")).to eq(
      "success" => true,
      "insertedRows" => 1,
    )
  end

  it "raises instead of inserting a row without any columns" do
    expect { proxy.insert_rows([{ "email" => "a@example.com" }, {}], "all") }.to raise_error(
      ArgumentError,
      /Cannot insert a row without any column/,
    )
    expect(count_data_table_rows(data_table)).to eq(0)
  end

  it "gets many rows and count" do
    insert_data_table_row(data_table, "email" => "a@example.com", "score" => 1)
    insert_data_table_row(data_table, "email" => "b@example.com", "score" => 2)

    result = proxy.get_many_rows_and_count(sort_by: %w[email DESC], take: 1)

    expect(result[:count]).to eq(2)
    expect(result[:data].map { |row| row["email"] }).to eq(["b@example.com"])
  end

  it "updates matching rows in one statement and returns them" do
    insert_data_table_row(data_table, "email" => "a@example.com", "score" => 1)
    insert_data_table_row(data_table, "email" => "b@example.com", "score" => 1)
    insert_data_table_row(data_table, "email" => "c@example.com", "score" => 2)
    filter = {
      "type" => "and",
      "filters" => [{ "columnName" => "score", "condition" => "eq", "value" => "1" }],
    }

    result = nil
    queries =
      track_sql_queries { result = proxy.update_rows(filter:, data: { "score" => "10" }, take: 1) }

    expect(queries.count { |query| query.include?("UPDATE") }).to eq(1)
    expect(result[:count]).to eq(2)
    expect(result[:data].map { |row| row.slice("email", "score") }).to eq(
      [{ "email" => "a@example.com", "score" => 10 }],
    )
  end

  it "upserts rows" do
    insert_data_table_row(data_table, "email" => "a@example.com", "score" => 1)

    updated_rows =
      proxy.upsert_row(filter: email_filter("a@example.com"), data: { "score" => "10" })
    inserted_rows =
      proxy.upsert_row(
        filter: email_filter("b@example.com"),
        data: {
          "email" => "b@example.com",
          "score" => "2",
        },
      )

    expect(updated_rows[:data].map { |row| row.slice("email", "score") }).to eq(
      [{ "email" => "a@example.com", "score" => 10 }],
    )
    expect(inserted_rows).to include(count: 1)
    expect(inserted_rows[:data].map { |row| row.slice("email", "score") }).to eq(
      [{ "email" => "b@example.com", "score" => 2 }],
    )
  end

  context "when there are no columns to write" do
    fab!(:row) { insert_data_table_row(data_table, "email" => "a@example.com", "score" => 1) }

    it "returns the matched rows unchanged on update and upsert" do
      %i[update_rows upsert_row].each do |method|
        expect(proxy.public_send(method, filter: email_filter("a@example.com"), data: {})).to eq(
          { data: [row], count: 1 },
        ),
        method.to_s
      end
      expect(find_data_table_row(data_table, row["id"])).to eq(row)
    end

    it "returns identical before and after rows on a dry run" do
      expected = {
        data: [row.merge("dryRunState" => "before"), row.merge("dryRunState" => "after")],
        count: 1,
      }

      %i[update_rows upsert_row].each do |method|
        expect(
          proxy.public_send(method, filter: email_filter("a@example.com"), data: {}, dry_run: true),
        ).to eq(expected),
        method.to_s
      end
    end

    it "raises on an upsert that matches nothing, including a dry run" do
      [false, true].each do |dry_run|
        expect {
          proxy.upsert_row(filter: email_filter("b@example.com"), data: {}, dry_run:)
        }.to raise_error(ArgumentError, /Cannot insert a row without any column/)
      end
      expect(count_data_table_rows(data_table)).to eq(1)
    end
  end

  it "deletes rows and returns deleted rows" do
    insert_data_table_row(data_table, "email" => "a@example.com", "score" => 1)
    insert_data_table_row(data_table, "email" => "b@example.com", "score" => 2)

    result = proxy.delete_rows(filter: email_filter("a@example.com"))

    expect(result[:count]).to eq(1)
    expect(result[:data].map { |row| row.slice("email", "score") }).to eq(
      [{ "email" => "a@example.com", "score" => 1 }],
    )
    expect(count_data_table_rows(data_table)).to eq(1)
  end

  it "requires filters for mutating row operations" do
    expect { proxy.update_rows(data: { "score" => "10" }) }.to raise_error(
      ArgumentError,
      /Filter must not be empty/,
    )
    expect { proxy.upsert_row(data: { "score" => "10" }) }.to raise_error(
      ArgumentError,
      /Filter must not be empty/,
    )
    expect { proxy.delete_rows({}) }.to raise_error(ArgumentError, /Filter must not be empty/)
  end

  it "manages table and column operations exposed by the proxy contract" do
    expect(proxy.update_data_table(name: "renamed_contacts")).to eq(true)
    expect(data_table.reload.name).to eq("renamed_contacts")

    column = proxy.add_column(name: "active", type: "boolean")
    expect(column).to include(name: "active", type: "boolean")

    expect(proxy.delete_column("active")).to eq(true)
    expect(proxy.get_columns.map { |c| c[:name] }).not_to include("active")
  end
end
