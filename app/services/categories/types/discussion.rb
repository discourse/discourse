# frozen_string_literal: true

module Categories
  module Types
    class Discussion < Base
      type_id :discussion

      class << self
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
