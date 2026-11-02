# frozen_string_literal: true

require Rails.root.join("db/post_migrate/20261021063131_finalize_access_control_list_source.rb")

RSpec.describe FinalizeAccessControlListSource do
  around { |example| ActiveRecord::Migration.suppress_messages { example.run } }

  it "finalizes source values without overwriting existing source values" do
    connection = ActiveRecord::Base.connection
    unless connection.column_exists?(:access_control_lists, :source)
      connection.add_column(:access_control_lists, :source, :string, limit: 100)
    end
    connection.change_column_null(:access_control_lists, :source, true)
    connection.change_column_null(:access_control_lists, :owner, true)

    legacy_acl_id = DB.query_single(<<~SQL).first
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
    default_acl_id = DB.query_single(<<~SQL).first
        INSERT INTO access_control_lists (
          target_type,
          target_id,
          permission,
          created_at,
          updated_at
        )
        VALUES ('Category', 2, 'view', NOW(), NOW())
        RETURNING id
      SQL
    existing_source_acl_id = DB.query_single(<<~SQL).first
        INSERT INTO access_control_lists (
          target_type,
          target_id,
          owner,
          source,
          permission,
          created_at,
          updated_at
        )
        VALUES ('Category', 3, 'legacy-plugin', 'new-plugin', 'view', NOW(), NOW())
        RETURNING id
      SQL

    described_class.new.up

    expect(DB.query_single(<<~SQL, legacy_acl_id:, default_acl_id:, existing_source_acl_id:)).to eq(
          SELECT source
          FROM access_control_lists
          WHERE id IN (:legacy_acl_id, :default_acl_id, :existing_source_acl_id)
          ORDER BY id
        SQL
      %w[test-plugin core new-plugin],
    )
    source_column =
      connection.columns(:access_control_lists).find { |column| column.name == "source" }
    expect(source_column.null).to eq(false)
  end
end
