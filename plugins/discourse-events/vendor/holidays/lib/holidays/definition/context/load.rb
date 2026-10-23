module Holidays
  module Definition
    module Context
      class Load
        def initialize(definition_merger, full_definitions_path)
          @definition_merger = definition_merger
          @full_definitions_path = full_definitions_path
        end

        def call(region)
          region_definition_file = "#{@full_definitions_path}/#{region}"
          require region_definition_file

          target_region_module = Module.const_get("Holidays").const_get(region.upcase)

          @definition_merger.call(
            region,
            target_region_module.holidays_by_month,
            target_region_module.custom_methods,
          )

          target_region_module.defined_regions
        rescue  NameError, LoadError => e
          raise UnknownRegionError.new(e), "Could not load region prefix: #{region.to_s}"
        end
      end
    end
  end
end
