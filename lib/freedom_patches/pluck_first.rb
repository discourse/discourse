# frozen_string_literal: true

class ActiveRecord::Relation
  def pluck_first(*attributes)
    limit(1).pluck(*attributes).first
  end

  def pluck_first!(*attributes)
    items = limit(1).pluck(*attributes)

    raise_record_not_found_exception! if items.empty?

    items.first
  end
end

module ActiveRecord::Querying
  delegate(:pluck_first, :pluck_first!, to: :all)
end
