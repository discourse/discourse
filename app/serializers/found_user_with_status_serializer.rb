# frozen_string_literal: true

class FoundUserWithStatusSerializer < FoundUserSerializer
  include UserStatusMixin

  def initialize(object, options = {})
    super
    options[:include_status] = true
  end
end
