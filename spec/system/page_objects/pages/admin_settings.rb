# frozen_string_literal: true

module PageObjects
  module Pages
    # TODO (martin) Remove this after discourse-topic-voting no longer
    # relies on this, it was renamed to AdminSiteSettings.
    class AdminSettings < PageObjects::Pages::AdminSiteSettings
    end
  end
end
