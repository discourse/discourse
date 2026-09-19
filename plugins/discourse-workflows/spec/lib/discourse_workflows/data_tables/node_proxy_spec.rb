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

  it "gets many rows and count" do
    insert_data_table_row(data_table, "email" => "a@example.com", "score" => 1)
    insert_data_table_row(data_table, "email" => "b@example.com", "score" => 2)

    result = proxy.get_many_rows_and_count(sort_by: %w[email DESC], take: 1)

    expect(result[:count]).to eq(2)
    expect(result[:data].map { |row| row["email"] }).to eq(["b@example.com"])
  end

  it "updates rows and returns updated rows" do
    insert_data_table_row(data_table, "email" => "a@example.com", "score" => 1)
    insert_data_table_row(data_table, "email" => "b@example.com", "score" => 2)

    rows = proxy.update_rows(filter: email_filter("a@example.com"), data: { "score" => "10" })

    expect(rows.map { |row| row.slice("email", "score") }).to eq(
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

    expect(updated_rows.map { |row| row.slice("email", "score") }).to eq(
      [{ "email" => "a@example.com", "score" => 10 }],
    )
    expect(inserted_rows.map { |row| row.slice("email", "score") }).to eq(
      [{ "email" => "b@example.com", "score" => 2 }],
    )
  end

  it "deletes rows and returns deleted rows" do
    insert_data_table_row(data_table, "email" => "a@example.com", "score" => 1)
    insert_data_table_row(data_table, "email" => "b@example.com", "score" => 2)

    rows = proxy.delete_rows(filter: email_filter("a@example.com"))

    expect(rows.map { |row| row.slice("email", "score") }).to eq(
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
