# frozen_string_literal: true

module DiscourseBoosts
  module NotificationExtension
    def types
      @types_with_boost ||= super.merge(boost: 43)
    end
  end
end
