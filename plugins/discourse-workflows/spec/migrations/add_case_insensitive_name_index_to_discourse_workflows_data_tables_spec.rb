# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-workflows/db/migrate/20261019104439_add_case_insensitive_name_index_to_discourse_workflows_data_tables.rb",
        )

RSpec.describe AddCaseInsensitiveNameIndexToDiscourseWorkflowsDataTables do
  TABLE = "discourse_workflows_data_tables"
  LOWER_NAME_INDEX = "idx_dwf_data_tables_on_lower_name"

  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    described_class.new.down
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  def insert(name)
    DB.query_single(
      "INSERT INTO #{TABLE} (name, created_at, updated_at) VALUES (:name, NOW(), NOW()) RETURNING id",
      name:,
    ).first
  end

  it "renames later case duplicates after their id and enforces case-insensitive uniqueness" do
    original = insert("Contacts")
    duplicate = insert("contacts")
    insert("orders")

    described_class.new.up

    expect(DB.query_single("SELECT name FROM #{TABLE} ORDER BY id")).to eq(
      ["Contacts", "contacts_#{duplicate}", "orders"],
    )
    expect(DB.query_single("SELECT id FROM #{TABLE} WHERE name = 'Contacts'")).to eq([original])
    expect(ActiveRecord::Base.connection.indexes(TABLE).map(&:name)).to include(LOWER_NAME_INDEX)
    expect { insert("ORDERS") }.to raise_error(PG::UniqueViolation)
  end

  it "skips generated names already taken by another table in any case" do
    insert("Contacts")
    duplicate = insert("contacts")
    insert("CONTACTS_#{duplicate}")

    described_class.new.up

    expect(DB.query_single("SELECT name FROM #{TABLE} WHERE id = :id", id: duplicate)).to eq(
      ["contacts_#{duplicate + 1}"],
    )
    expect(ActiveRecord::Base.connection.indexes(TABLE).map(&:name)).to include(LOWER_NAME_INDEX)
  end
end
