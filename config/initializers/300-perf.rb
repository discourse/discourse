# frozen_string_literal: true

if Rails.env == "production"
  # This event happens quite a lot and fans out to ExplainSubscriber
  # and Logger, this cuts out 2 method calls that every time we run SQL
  #
  # In production we do not care about Explain or Logging SQL statements
  # at this level
  #
  # Micro bench shows for `User.first` this takes us from 3.3k/s to 3.5k/s
  ActiveSupport::Notifications.notifier.unsubscribe("sql.active_record")
end

# this hook can be used by plugins to amend the middleware stack or patch any initializer behavior
DiscourseEvent.trigger(:after_initializers)
