# frozen_string_literal: true

class UserNotificationRenderer < ActionView::Base
  include ApplicationHelper
  include UserNotificationsHelper
  include EmailHelper

  LOCK = Mutex.new

  class << self
    def render(*args)
      LOCK.synchronize do
        @instance ||=
          UserNotificationRenderer.with_empty_template_cache.with_view_paths(
            Rails.configuration.paths["app/views"],
          )
        @instance.render(*args)
      end
    end
  end
end
