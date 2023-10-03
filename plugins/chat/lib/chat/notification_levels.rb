# frozen_string_literal: true

module Chat
  class NotificationLevels
    def self.all
      @all_levels ||= Enum.new(muted: 0, normal: 1, tracking: 2, watching: 3)
    end
  end
end
