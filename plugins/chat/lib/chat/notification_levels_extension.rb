# frozen_string_literal: true

module Chat
  module NotificationLevelsExtension
    extend ActiveSupport::Concern

    class_methods do
      def chat_levels
        @chat_levels ||= Enum.new(muted: 0, normal: 1, tracking: 2, watching: 3)
      end
    end
  end
end
