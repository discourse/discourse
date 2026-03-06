# frozen_string_literal: true

module Categories
  module Types
    class Discussion < Base
      type_id :discussion

      class << self
        def find_matches
          # NOTE (martin) This is obviously not correct, but we need some placeholder here.
          # Like I say below, all categories are considered discussion categories,
          # so we need to return an empty relation here.
          #
          # We probably won't need to have a count specifically for discussion categories,
          # but we need to return something here to avoid errors.
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
