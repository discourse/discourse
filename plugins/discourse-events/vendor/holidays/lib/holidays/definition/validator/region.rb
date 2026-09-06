module Holidays
  module Definition
    module Validator
      class Region
        def initialize(regions_repo)
          @regions_repo = regions_repo
        end

        def valid?(r)
          return false unless r.is_a?(Symbol)

          region = find_wildcard_base(r)

          (region == :any ||
           @regions_repo.loaded?(region) ||
           @regions_repo.all_generated.include?(region))
        end

        private

        # Ex: :gb_ transformed to :gb
        def find_wildcard_base(region)
          r = region.to_s

          if r =~ /_$/
            base = r.split('_').first
          else
            base = r
          end

          base.to_sym
        end
      end
    end
  end
end
