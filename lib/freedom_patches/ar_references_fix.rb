# frozen_string_literal: true

# This patch is a backport of https://github.com/rails/rails/pull/42350
# It fixes a bug introduced by Rails which affects reference columns marking
# them as integer instead of bigint.
#
# This should be deleted when version 7.0.3 is released.
module FreedomPatches
  module ArReferencesFix
    module SchemaDefinition
      def index_options(table_name)
        index_options = as_options(index)

        # legacy reference index names are used on versions 6.0 and earlier
        return index_options if options[:_uses_legacy_reference_index_name]

        index_options[:name] ||= polymorphic_index_name(table_name) if polymorphic
        index_options
      end

      ActiveRecord::ConnectionAdapters::ReferenceDefinition.prepend(self)
    end
  end
end

class ActiveRecord::Migration::Compatibility::V6_0
  module TableDefinition
    def references(*args, **options)
      options[:_uses_legacy_reference_index_name] = true
      super
    end
    alias :belongs_to :references
  end

  def add_reference(table_name, ref_name, **options)
    if connection.adapter_name == "SQLite"
      options[:type] = :integer
    end
    options[:_uses_legacy_reference_index_name] = true
    super
  end
  alias :add_belongs_to :add_reference

  def compatible_table_definition(t)
    class << t
      prepend TableDefinition
    end
    super
  end
end
