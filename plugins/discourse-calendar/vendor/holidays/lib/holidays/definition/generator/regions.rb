module Holidays
  module Definition
    module Generator
      class Regions
        # The "ca", "mx", and "us" holiday definitions include the "northamericainformal"
        # holiday definitions, but that does not make these countries subregions of one another.
        NORTH_AMERICA_REGIONS = %i[ca mx us].freeze

        def call(regions)
          validate!(regions)

          <<-EOF
# encoding: utf-8
module Holidays
  REGIONS = #{to_array(regions)}

  PARENT_REGION_LOOKUP = #{generate_parent_lookup(regions)}
end
EOF
        end

        private

        def validate!(regions)
          raise ArgumentError.new("regions cannot be missing") if regions.nil?
          raise ArgumentError.new("regions must be a hash") unless regions.is_a?(Hash)
          raise ArgumentError.new("regions cannot be empty") if regions.empty?
        end

        def to_array(regions)
          all_regions = []

          regions.each do |region, subregions|
            all_regions << subregions
          end

          all_regions.flatten.uniq
        end

        def generate_parent_lookup(regions)
          lookup = {}

          regions.each do |region, subregions|
            subregions.each do |subregion|
              parent_region = NORTH_AMERICA_REGIONS.include?(subregion) ? subregion : region
              lookup[subregion] = parent_region unless lookup.has_key?(subregion)
            end
          end

          lookup
        end
      end
    end
  end
end
