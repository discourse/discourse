# frozen_string_literal: true

# Cached column metadata stores Postgres type OIDs — db/schema_cache.yml in
# development, each pool's in-memory schema cache in production. Custom types
# (enums such as hotlinked_media_status) get a new OID whenever a database is
# recreated or a backup is restored, while cached metadata keeps the old one.
# After a restore the old type even keeps resolving for a while (it survives
# in the backup schema, OID intact, until that schema is dropped) — and then
# every schema load from stale metadata fails to type the column, so models
# using `enum` raise "Undeclared attribute type for enum".
#
# Models type their columns through lookup_cast_type_from_column, which only
# consults the connection's in-memory type map and silently falls back to a
# plain value type on a miss. When the cached OID is unknown, retry by type
# name before giving up: a same-named type in the search path is the
# recreated incarnation of the cached one. The result is registered under the
# cached OID, so each connection resolves a given OID at most once and
# lookups of known OIDs pay only the key check.
#
# TODO: remove once the equivalent fix lands upstream in rails/rails
# (activerecord: PostgreSQL::Quoting#lookup_cast_type_from_column).

module FreedomPatches
  module SchemaCacheStaleTypeOid
    def lookup_cast_type_from_column(column)
      verify! if type_map.nil?
      oid = column.oid
      register_uncached_oid(oid, column.sql_type) if oid && !type_map.key?(oid)
      super
    end

    private

    def register_uncached_oid(oid, sql_type)
      load_additional_types([oid])
      return if type_map.key?(oid)

      current_oid = current_oid_for_type_name(sql_type)

      if current_oid && current_oid != oid
        load_additional_types([current_oid]) unless type_map.key?(current_oid)
        type_map.alias_type(oid, current_oid)
      else
        # Same fallback Rails uses for unknown OIDs, registered so the miss is
        # not retried on every lookup.
        type_map.register_type(oid, ActiveRecord::Type.default_value)
      end
    rescue ActiveRecord::StatementInvalid
      nil
    end

    # Only simple (optionally schema-qualified, optionally array) type names
    # are worth resolving — built-in types with exotic sql_types have fixed
    # OIDs and can never be stale. to_regtype respects the search path, so a
    # type of the same name lingering in another schema (e.g. the restore's
    # backup schema) does not match.
    def current_oid_for_type_name(sql_type)
      return nil if sql_type.blank?
      name = sql_type.delete_suffix("[]")
      return nil unless name.match?(/\A(?:[a-zA-Z_][\w$]*\.)?[a-zA-Z_][\w$]*\z/)

      result =
        internal_execute(
          "SELECT to_regtype(#{quote(sql_type)})::oid AS oid",
          "SCHEMA",
          [],
          allow_retry: true,
          materialize_transactions: false,
        )
      result.first&.fetch("oid", nil)&.to_i
    end
  end
end

ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend(FreedomPatches::SchemaCacheStaleTypeOid)
