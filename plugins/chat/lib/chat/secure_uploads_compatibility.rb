# frozen_string_literal: true

module Chat
  class SecureUploadsCompatibility
    ##
    # At this point in time, secure uploads is not compatible with chat,
    # so if it is enabled then chat uploads must be disabled to avoid undesirable
    # behaviour.
    #
    # The env var DISCOURSE_ALLOW_UNSECURE_CHAT_UPLOADS can be set to keep
    # it enabled, but this is strongly advised against.
    def self.update_settings
      if SiteSetting.secure_uploads && SiteSetting.chat_allow_uploads &&
           !GlobalSetting.allow_unsecure_chat_uploads
        SiteSetting.chat_allow_uploads = false
        StaffActionLogger.new(Discourse.system_user).log_site_setting_change(
          "chat_allow_uploads",
          true,
          false,
          context: "Disabled because secure_uploads is enabled",
        )
      end
    end
  end
end
