# frozen_string_literal: true

module DiscourseRewind
  # Service responsible for dismissing Rewind for the user.
  #
  # @example
  #  ::DiscourseRewind::Dismiss.call(guardian: guardian)
  #
  class Dismiss
    include Service::Base

    # @!method self.call(guardian:)
    #   @param [Guardian] guardian
    #   @return [Service::Base::Context]

    step :dismiss

    private

    def dismiss(guardian:)
      guardian.user.user_option.update!(discourse_rewind_dismissed_at: Time.zone.now)
    end
  end
end
