# frozen_string_literal: true

class UserNotificationRenderer < ActionView::Base
  include ApplicationHelper
  include UserNotificationsHelper
  include EmailHelper
end
