class UserOptionSerializer < ApplicationSerializer
  attributes :user_id,
             :email_always,
             :mailing_list_mode,
             :mailing_list_mode_frequency,
             :email_digests,
             :email_private_messages,
             :email_direct,
             :external_links_in_new_tab,
             :dynamic_favicon,
             :enable_quoting,
             :disable_jump_reply,
             :digest_after_minutes,
             :automatically_unpin_topics,
             :edit_history_public,
             :auto_track_topics_after_msecs,
             :new_topic_duration_minutes,
             :email_previous_replies,
             :email_in_reply_to,
             :like_notification_frequency,
             :include_tl0_in_digests


  def include_edit_history_public?
    !SiteSetting.edit_history_visible_to_public
  end

  def auto_track_topics_after_msecs
    object.auto_track_topics_after_msecs || SiteSetting.default_other_auto_track_topics_after_msecs
  end

  def new_topic_duration_minutes
    object.new_topic_duration_minutes || SiteSetting.default_other_new_topic_duration_minutes
  end

end
