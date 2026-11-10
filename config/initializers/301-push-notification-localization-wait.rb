# frozen_string_literal: true

DiscourseEvent.on(:post_localization_saved) do |localization|
  PushNotificationLocalizationWait.release(localization.post_id, locale: localization.locale)
end

# Triggered by translators once they are done with a post, whether or not they
# stored a translation for every locale.
DiscourseEvent.on(:post_localizations_finished) do |post_id|
  PushNotificationLocalizationWait.finish(post_id)
end
