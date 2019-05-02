# frozen_string_literal: true

# Speeds up #pluck so its about 2.2x faster, importantly makes pluck avoid creation of a slew
# of AR objects
#
#
class ActiveRecord::Relation

  # Note: In discourse, the following code is included in lib/sql_builder.rb
  #
  # class RailsDateTimeDecoder < PG::SimpleDecoder
  #   def decode(string, tuple=nil, field=nil)
  #     if Rails.version >= "4.2.0"
  #       @caster ||= ActiveRecord::Type::DateTime.new
  #       @caster.type_cast_from_database(string)
  #     else
  #       ActiveRecord::ConnectionAdapters::Column.string_to_time string
  #     end
  #   end
  # end
  #
  # class ActiveRecordTypeMap < PG::BasicTypeMapForResults
  #   def initialize(connection)
  #     super(connection)
  #     rm_coder 0, 1114
  #     add_coder RailsDateTimeDecoder.new(name: "timestamp", oid: 1114, format: 0)
  #     # we don't need deprecations
  #     self.default_type_map = PG::TypeMapInRuby.new
  #   end
  # end
  #
  # def self.pg_type_map
  #   conn = ActiveRecord::Base.connection.raw_connection
  #   @typemap ||= ActiveRecordTypeMap.new(conn)
  # end

  class ::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
    def select_raw(arel, name = nil, binds = [], &block)
      arel = arel_from_relation(arel)
      sql, binds = to_sql_and_binds(arel, binds)
      execute_and_clear(sql, name, binds, &block)
    end
  end

  def pluck(*column_names)
    if loaded? && (column_names.map(&:to_s) - @klass.attribute_names - @klass.attribute_aliases.keys).empty?
      return records.pluck(*column_names)
    end

    if has_include?(column_names.first)
      relation = apply_join_dependency
      relation.pluck(*column_names)
    else
      enforce_raw_sql_whitelist(column_names)
      relation = spawn

      relation.select_values = column_names.map { |cn|
        @klass.has_attribute?(cn) || @klass.attribute_alias?(cn) ? arel_attribute(cn) : cn
      }

      klass.connection.select_raw(relation.arel) do |result, _|
        result.type_map = DB.type_map
        result.nfields == 1 ? result.column_values(0) : result.values
      end
    end
  end
end

# require 'benchmark/ips'
#
# ENV['RAILS_ENV'] = 'production'
# require File.expand_path("../../config/environment", __FILE__)
#
# Benchmark.ips do |x|
#   x.report("fast_pluck") do
#     Post.where(topic_id: 48464).fast_pluck(:id)
#   end
#
#   x.report("pluck") do
#     Post.where(topic_id: 48464).pluck(:id)
#   end
# end
#
# % ruby tmp/fast_pluck.rb
# Calculating -------------------------------------
#           fast_pluck   165.000  i/100ms
#                pluck    80.000  i/100ms
# -------------------------------------------------
#           fast_pluck      1.720k (± 8.8%) i/s -      8.580k
#                pluck    807.913  (± 4.0%) i/s -      4.080k
#
