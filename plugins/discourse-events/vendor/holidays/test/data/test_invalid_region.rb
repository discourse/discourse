module Holidays
  module BAD_REGION_NAME
    def self.defined_regions
      [:test_region]
    end

    def self.holidays_by_month
      {}
    end

    def self.custom_methods
      {}
    end
  end
end
