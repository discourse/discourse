module Holidays
  module Finder
    module Rules
      class InRegion
        class << self
          def call(requested, available)
            return true if requested.include?(:any)

            # When an underscore is encountered, derive the parent regions
            # symbol and check for both.
            requested = requested.collect do |r|
              if r.to_s =~ /_/
                chunks = r.to_s.split('_')

                chunks.length.downto(1).map do |num|
                  chunks[0..-num].join('_').to_sym
                end
              else
                r
              end
            end

            requested = requested.flatten.uniq

            available.any? { |avail| requested.include?(avail) }
          end
        end
      end
    end
  end
end
