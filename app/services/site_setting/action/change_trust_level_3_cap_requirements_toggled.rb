# frozen_string_literal: true

class SiteSetting::Action::ChangeTrustLevel3CapRequirementsToggled < Service::ActionBase
  option :enabled, :boolean

  # The default for tl3_requires_topics_viewed_cap is reduced from 500 to 250
  # The default for tl3_requires_posts_read_cap is reduced from 20000 to 2000
  # The default for tl3_promotion_min_duration is increased from 14 days to 100 days
  # All existing forums that have not changed these parameters get the new values
  # New forums start with these values

  def call
    if enabled
      detailed_message =
        "Automatically changed as a side-effect of 'Change trust level 3 cap requirements' upcoming change being enabled"
      # Change all to the new default values if they are not already changed by admins
      unless SiteSetting.modified[:tl3_requires_topics_viewed_cap]
        SiteSetting.set_and_log(
          :tl3_requires_topics_viewed_cap,
          250,
          Discourse.system_user,
          detailed_message,
        )
      end
      unless SiteSetting.modified[:tl3_requires_posts_read_cap]
        SiteSetting.set_and_log(
          :tl3_requires_posts_read_cap,
          2000,
          Discourse.system_user,
          detailed_message,
        )
      end
      unless SiteSetting.modified[:tl3_promotion_min_duration]
        SiteSetting.set_and_log(
          :tl3_promotion_min_duration,
          100,
          Discourse.system_user,
          detailed_message,
        )
      end
    else
      detailed_message =
        "Automatically changed as a side-effect of 'Change trust level 3 cap requirements' upcoming change being disabled"
      # Revert back to the old default values if they are not already changed by admins
      unless SiteSetting.modified[:tl3_requires_topics_viewed_cap]
        SiteSetting.set_and_log(
          :tl3_requires_topics_viewed_cap,
          500,
          Discourse.system_user,
          detailed_message,
        )
      end
      unless SiteSetting.modified[:tl3_requires_posts_read_cap]
        SiteSetting.set_and_log(
          :tl3_requires_posts_read_cap,
          20_000,
          Discourse.system_user,
          detailed_message,
        )
      end
      unless SiteSetting.modified[:tl3_promotion_min_duration]
        SiteSetting.set_and_log(
          :tl3_promotion_min_duration,
          14,
          Discourse.system_user,
          detailed_message,
        )
      end
    end
  end
end
