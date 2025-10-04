# frozen_string_literal: true

module DiscourseSharedEdits
  module GuardianExtension
    extend ActiveSupport::Concern

    def can_toggle_shared_edits?
      SiteSetting.shared_edits_enabled && authenticated? &&
        (is_staff? || @user.has_trust_level?(TrustLevel[4]))
    end
  end
end
