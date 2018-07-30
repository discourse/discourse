module PreserveOrder
  extend ActiveSupport::Concern

  included do
    scope :where_ordered, ->(hash) {
      return none unless hash.present?

      column, values = hash.first
      where(column => values)
        .order("position(#{column}::text in '#{values.join(',')}')")
    }
  end
end
