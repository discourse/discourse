# frozen_string_literal: true

module Migrations::Database::Schema::DSL
end

# Each DSL file defines multiple constants (Data classes + builders),
# so we require them explicitly rather than relying on Zeitwerk's
# one-file-one-constant convention.
require_relative "dsl/registry"
require_relative "dsl/config"
require_relative "dsl/conventions"
require_relative "dsl/enum_definition"
require_relative "dsl/ignored_tables"
require_relative "dsl/table_definition"
require_relative "dsl/plugin_introspector"
require_relative "dsl/plugin_manifest"
require_relative "dsl/loader"
