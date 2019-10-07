# frozen_string_literal: true

class UserNotificationRenderer < ActionView::Base
  include ApplicationHelper
  include UserNotificationsHelper
  include EmailHelper

  def self.instance
    @instance ||= UserNotificationRenderer.with_view_paths(
      Rails.configuration.paths["app/views"]
    )
  end
end
