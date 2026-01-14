module Holidays
  module Definition
    module Repository
      class Regions
        def initialize(all_generated_regions, parent_region_lookup)
          @loaded_regions = []
          @all_generated_regions = all_generated_regions
          @parent_region_lookup = parent_region_lookup
        end

        def all_generated
          @all_generated_regions
        end

        def parent_region_lookup(r)
          @parent_region_lookup[r]
        end

        def all_loaded
          @loaded_regions
        end

        def loaded?(region)
          raise ArgumentError unless region.is_a?(Symbol)
          @loaded_regions.include?(region)
        end

        def add(regions)
          regions = [regions] unless regions.is_a?(Array)

          regions.each do |region|
            raise ArgumentError unless region.is_a?(Symbol)
          end

          @loaded_regions = @loaded_regions | regions
          @loaded_regions.uniq!
        end

        def search(prefix)
          raise ArgumentError unless prefix.is_a?(Symbol)
          @loaded_regions.select { |region| region.to_s =~ Regexp.new("^#{prefix}") }
        end
      end
    end
  end
end
