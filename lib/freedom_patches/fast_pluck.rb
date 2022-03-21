# frozen_string_literal: true

# Speeds up #pluck so its about 2.2x faster, importantly makes pluck avoid creation of a slew
# of AR objects

SanePatch.patch("activerecord", "~> 7.0.2") do
  module FreedomPatches
    module FastPluck
      module Relation
        def pluck(*column_names)
          if loaded? && (column_names.map(&:to_s) - @klass.attribute_names - @klass.attribute_aliases.keys).empty?
            return records.pluck(*column_names)
          end

          if has_include?(column_names.first)
            relation = apply_join_dependency
            relation.pluck(*column_names)
          else
            relation = spawn

            relation.select_values = column_names

            klass.connection.select_raw(relation.arel) do |result, _|
              result.type_map = DB.type_map
              result.nfields == 1 ? result.column_values(0) : result.values
            end
          end
        end
      end

      module PostgreSQLAdapter
        def select_raw(arel, name = nil, binds = [], &block)
          arel = arel_from_relation(arel)
          sql, binds = to_sql_and_binds(arel, binds)
          execute_and_clear(sql, name, binds, &block)
        end
      end

      ActiveRecord::Relation.prepend(Relation)
      ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend(PostgreSQLAdapter)
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
