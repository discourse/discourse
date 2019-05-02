# frozen_string_literal: true

module Searchable
  extend ActiveSupport::Concern

  PRIORITIES = Enum.new(
    ignore: 1,
    very_low: 2,
    low: 3,
    normal: 0,
    high: 4,
    very_high: 5
  )

  included do
    has_one "#{self.name.underscore}_search_data".to_sym, dependent: :destroy
  end
end
