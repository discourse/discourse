# frozen_string_literal: true

module DiscourseEvents
  module GroupTimezones
    class UserSerializer < BasicUserSerializer
      attributes :timezone, :on_holiday

      def on_holiday
        @options[:on_holiday] || false
      end
    end
  end
end
