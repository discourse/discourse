module Holidays
  module Definition
    module Context
      # Merge a new set of definitions into the Holidays module.
      class Merger
        def initialize(holidays_by_month_repo, regions_repo, custom_methods_repo)
          @holidays_repo = holidays_by_month_repo
          @regions_repo = regions_repo
          @custom_methods_repo = custom_methods_repo
        end

        def call(target_regions, target_holidays, target_custom_methods)
          #FIXME Does this need to come in this exact order? God I hope not.
          # If not then we should swap the order so it matches the init.
          @regions_repo.add(target_regions)
          @holidays_repo.add(target_holidays)
          @custom_methods_repo.add(target_custom_methods)
        end
      end
    end
  end
end
