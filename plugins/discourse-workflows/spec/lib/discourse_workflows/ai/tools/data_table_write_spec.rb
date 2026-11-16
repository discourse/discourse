# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Ai::Tools::DataTableWrite do
  fab!(:admin)
  fab!(:user)
  fab!(:data_table) do
    Fabricate(
      :discourse_workflows_data_table,
      name: "contacts",
      columns: [{ name: "email", type: "string" }, { name: "score", type: "number" }],
    )
  end

  def email_filter(email = "a@example.com")
    { filters: [{ columnName: "email", condition: "eq", value: email }] }
  end

  def invoke(user: admin, **params)
    invoke_ai_tool(described_class, params, user:)
  end

  def emails
    list_data_table_rows(data_table)[:rows].map { |row| row["email"] }
  end

  it "inserts, updates, upserts and deletes rows" do
    inserted = invoke(table: "contacts", operation: "insert", data: { email: "a@example.com" })
    expect(inserted).to include(status: "success", operation: "insert", count: 1)
    expect(emails).to eq(%w[a@example.com])

    updated =
      invoke(table: "contacts", operation: "update", filter: email_filter, data: { score: 7 })
    expect(updated).to include(operation: "update", count: 1)

    upserted =
      invoke(
        table: "contacts",
        operation: "upsert",
        filter: email_filter("b@example.com"),
        data: {
          email: "b@example.com",
        },
      )
    expect(upserted).to include(operation: "upsert", count: 1)

    deleted = invoke(table: "contacts", operation: "delete", filter: email_filter)
    expect(deleted).to include(operation: "delete", count: 1)
    expect(emails).to eq(%w[b@example.com])
  end

  it "rejects unsupported operations, unknown tables and missing data before approval" do
    expect(
      build_ai_tool(
        described_class,
        { table: "nope", operation: "truncate" },
        user: admin,
      ).validation_error,
    ).to eq(status: "error", error: "Unknown data table 'nope'")
    expect(invoke(table: "contacts", operation: "truncate")).to eq(
      status: "error",
      error: "Unsupported operation 'truncate'",
    )
    expect(invoke(table: "contacts", operation: "update", filter: email_filter)).to eq(
      status: "error",
      error: "data is required",
    )
    expect(
      build_ai_tool(
        described_class,
        { table: "contacts", operation: "delete" },
        user: admin,
      ).validation_error,
    ).to match(status: "error", error: /Filter must not be empty/)
  end

  it "rejects invalid insert data before approval without writing" do
    expect(
      build_ai_tool(
        described_class,
        { table: "contacts", operation: "insert", data: { score: "not a number" } },
        user: admin,
      ).validation_error,
    ).to include(status: "error")
    expect(
      build_ai_tool(
        described_class,
        { table: "contacts", operation: "insert", data: { nope: "x" } },
        user: admin,
      ).validation_error,
    ).to include(status: "error")
    expect(emails).to be_empty
  end

  it "denies users who cannot manage workflows without writing" do
    expect(invoke(table: "contacts", operation: "insert", data: { email: "x" }, user: user)).to eq(
      status: "error",
      error: I18n.t("invalid_access"),
    )
    expect(emails).to be_empty
  end
end
