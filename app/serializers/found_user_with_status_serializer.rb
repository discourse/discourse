# frozen_string_literal: true

class FoundUserWithStatusSerializer < FoundUserSerializer
  include UserStatusMixin

  def initialize(object, options = {})
    super
    options[:include_status] = true
    deprecated
  end

  private

  def deprecated
    message =
      "FoundUserWithStatusSerializer is deprecated. " \
        "Use FoundUserSerializer with the include_status option instead."

    Discourse.deprecate(message, since: "3.2.0", drop_from: "3.3.0.beta1")
  end
end
