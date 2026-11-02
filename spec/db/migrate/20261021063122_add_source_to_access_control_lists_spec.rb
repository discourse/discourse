# frozen_string_literal: true

require Rails.root.join("db/migrate/20261021063122_add_source_to_access_control_lists.rb")

RSpec.describe AddSourceToAccessControlLists do
  around { |example| ActiveRecord::Migration.suppress_messages { example.run } }

  it "adds and backfills source while allowing legacy owner values to be omitted" do
    connection = ActiveRecord::Base.connection
    if connection.column_exists?(:access_control_lists, :source)
      connection.remove_column(:access_control_lists, :source)
    end
    connection.change_column_null(:access_control_lists, :owner, false)

    acl_id = DB.query_single(<<~SQL).first
        INSERT INTO access_control_lists (
          target_type,
          target_id,
          owner,
          permission,
          created_at,
          updated_at
        )
        VALUES ('Category', 1, 'test-plugin', 'view', NOW(), NOW())
        RETURNING id
      SQL

    described_class.new.up

    expect(
      DB.query_single("SELECT owner, source FROM access_control_lists WHERE id = :acl_id", acl_id:),
    ).to eq(%w[test-plugin test-plugin])
    owner_column =
      connection.columns(:access_control_lists).find { |column| column.name == "owner" }
    expect(owner_column.null).to eq(true)

    expect { DB.exec(<<~SQL) }.not_to raise_error
        INSERT INTO access_control_lists (
          target_type,
          target_id,
          source,
          permission,
          created_at,
          updated_at
        )
        VALUES ('Category', 2, 'core', 'view', NOW(), NOW())
      SQL
  end
end
