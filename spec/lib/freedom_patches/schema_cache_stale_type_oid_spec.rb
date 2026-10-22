# frozen_string_literal: true

RSpec.describe FreedomPatches::SchemaCacheStaleTypeOid do
  # InvalidOid: Postgres never assigns it, so it can only ever be stale.
  let(:stale_oid) { 0 }
  let(:connection) { ActiveRecord::Base.connection }

  # Registrations land in the connection's type map, which outlives the
  # example's transaction.
  after { connection.reload_type_map }

  def column_with_stale_oid(sql_type)
    metadata =
      ActiveRecord::ConnectionAdapters::PostgreSQL::TypeMetadata.new(
        ActiveRecord::ConnectionAdapters::SqlTypeMetadata.new(sql_type: sql_type, type: :enum),
        oid: stale_oid,
        fmod: -1,
      )

    ActiveRecord::ConnectionAdapters::PostgreSQL::Column.new("status", nil, metadata, false)
  end

  def schema_queries
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] if payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries
  end

  describe "#lookup_cast_type_from_column" do
    it "resolves a stale OID through the type's current name" do
      type =
        connection.lookup_cast_type_from_column(column_with_stale_oid("hotlinked_media_status"))

      expect(type).to be_a(ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Enum)
    end

    it "remembers the resolved type so later lookups of the stale OID do not query" do
      column = column_with_stale_oid("hotlinked_media_status")
      connection.lookup_cast_type_from_column(column)

      type = nil
      queries = schema_queries { type = connection.lookup_cast_type_from_column(column) }

      expect(queries).to be_empty
      expect(type).to be_a(ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Enum)
    end

    it "does not query when the column's OID is known" do
      column = PostHotlinkedMedia.columns_hash["status"]

      queries = schema_queries { connection.lookup_cast_type_from_column(column) }

      expect(queries).to be_empty
    end

    it "falls back to the default value type, without querying by name, for sql types that are not plain identifiers" do
      queries =
        schema_queries do
          expect(
            connection.lookup_cast_type_from_column(
              column_with_stale_oid("character varying(255)"),
            ),
          ).to be_an_instance_of(ActiveModel::Type::Value)
        end

      expect(queries).not_to include(a_string_including("to_regtype"))
    end

    it "falls back to the default value type for type names that do not exist, and does not retry" do
      column = column_with_stale_oid("schema_cache_stale_type_oid_missing")

      expect(connection.lookup_cast_type_from_column(column)).to be_an_instance_of(
        ActiveModel::Type::Value,
      )
      expect(schema_queries { connection.lookup_cast_type_from_column(column) }).to be_empty
    end

    it "only matches types in the search path, unless the name is schema-qualified" do
      connection.execute(<<~SQL)
        CREATE SCHEMA schema_cache_stale_type_oid_spec;
        CREATE TYPE schema_cache_stale_type_oid_spec.parked_status AS ENUM ('ok');
      SQL

      unqualified = connection.lookup_cast_type_from_column(column_with_stale_oid("parked_status"))
      connection.reload_type_map
      qualified =
        connection.lookup_cast_type_from_column(
          column_with_stale_oid("schema_cache_stale_type_oid_spec.parked_status"),
        )

      expect(unqualified).to be_an_instance_of(ActiveModel::Type::Value)
      expect(qualified).to be_a(ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Enum)
    end
  end
end
