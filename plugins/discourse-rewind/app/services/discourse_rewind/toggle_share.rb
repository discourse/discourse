# frozen_string_literal: true

module DiscourseRewind
  # Service responsible for toggling the user's public sharing preference for Rewind.
  #
  # @example
  #  ::DiscourseRewind::ToggleShare.call(guardian: guardian)
  #
  class ToggleShare
    include Service::Base

    # @!method self.call(guardian:)
    #   @param [Guardian] guardian
    #   @return [Service::Base::Context]

    step :toggle_share_preference

    private

    def toggle_share_preference(guardian:)
      guardian.user.user_option.update!(
        discourse_rewind_share_publicly: !guardian.user.user_option.discourse_rewind_share_publicly,
      )
    end
  end
end
