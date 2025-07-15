# frozen_string_literal: true

class UserTimezoneSerializer < BasicUserSerializer
  attributes :timezone, :on_holiday

  def on_holiday
    @options[:on_holiday] || false
  end
end
