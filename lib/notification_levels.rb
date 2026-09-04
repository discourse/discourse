# frozen_string_literal: true

module NotificationLevels
  class << self
    def all
      @all_levels ||=
        Enum.new(
          muted: 0,
          regular: 1,
          normal: 1, # alias for regular
          tracking: 2,
          watching: 3,
          watching_first_post: 4,
        )
    end

    def topic_levels
      @topic_levels ||=
        Enum.new(
          muted: 0,
          regular: 1,
          normal: 1, # alias for regular
          tracking: 2,
          watching: 3,
        )
    end
  end
end
