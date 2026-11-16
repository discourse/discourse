# frozen_string_literal: true

class DottedRouteConstraint < Array
  def initialize(regexp)
    super([regexp])
    freeze
  end

  def to_s
    first.to_s
  end
end
