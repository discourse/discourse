# Speeds up #pluck so its about 2.2x faster, importantly makes pluck avoid creation of a slew
# of AR objects

require_dependency 'sql_builder'

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
    if Rails.version >= "4.2.0"
      def select_raw(arel, name = nil, binds = [], &block)
        arel, binds = binds_from_relation arel, binds
        sql = to_sql(arel, binds)
        execute_and_clear(sql, name, binds, &block)
      end
    else

      def select_raw(arel, name = nil, binds = [], &block)
        arel, binds = binds_from_relation arel, binds
        sql = to_sql(arel, binds)

        result = without_prepared_statement?(binds) ? exec_no_cache(sql, 'SQL', binds) :
                                                        exec_cache(sql, 'SQL', binds)
        yield result, nil
      end
    end
  end

  def pluck(*cols)

    conn = ActiveRecord::Base.connection
    relation = self

    cols.map! do |column_name|
      if column_name.is_a?(Symbol) && attribute_alias?(column_name)
        attribute_alias(column_name)
      else
        column_name.to_s
      end
    end


    if has_include?(cols.first)
      construct_relation_for_association_calculations.pluck(*cols)
    else
      relation = spawn

      relation.select_values = cols.map { |cn|
        columns_hash.key?(cn) ? arel_table[cn] : cn
      }

      conn.select_raw(relation) do |result,_|
        result.type_map = SqlBuilder.pg_type_map
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
