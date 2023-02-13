# frozen_string_literal: true

class ActiveRecord::Relation
  def pluck_first(*attributes)
    Discourse.deprecate("`#pluck_first` is deprecated, use `#pick` instead.")
    pick(*attributes)
  end

  def pluck_first!(*attributes)
    Discourse.deprecate("`#pluck_first!` is deprecated without replacement.")
    items = pick(*attributes)

    raise_record_not_found_exception! if items.nil?

    items
  end
end

module ActiveRecord::Querying
  delegate(:pluck_first, :pluck_first!, to: :all)
end
