# frozen_string_literal: true

module Categories
  module Types
    class Discussion < Base
      type_id :discussion

      class << self
        def find_matches
          # All categories are implicitly discussion categories, so there's no
          # meaningful subset to count. Returning Category.none keeps count at 0,
          # which means discussion always prefills — correct since it has no
          # general_category_settings to prefill anyway.
          Category.none
        end

        def category_matches?(category)
          # NOTE (martin) For now, all categories are considered discussion categories,
          # a discussion category is basically the old "vanilla" category type
          # for Discourse.
          #
          # Discussion categories don't have a special tab to show their settings like
          # e.g. Solved
          #
          # Maybe we will reconsider this in future iterations.
          true
        end
      end
    end
  end
end
