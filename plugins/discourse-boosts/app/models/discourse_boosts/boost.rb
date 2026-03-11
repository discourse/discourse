# frozen_string_literal: true

module DiscourseBoosts
  class Boost < ActiveRecord::Base
    self.table_name = "discourse_boosts"

    belongs_to :post
    belongs_to :user

    validates :raw, presence: true, length: { maximum: 16 }
    validates :cooked, presence: true

    before_validation :cook_raw, if: :will_save_change_to_raw?

    MARKDOWN_FEATURES = %w[emoji]
    MARKDOWN_IT_RULES = []

    def self.cook(raw)
      PrettyText.cook(
        raw.to_s.strip,
        features_override: MARKDOWN_FEATURES,
        markdown_it_rules: MARKDOWN_IT_RULES,
      )
    end

    private

    def cook_raw
      self.cooked = self.class.cook(self.raw)
    end
  end
end
