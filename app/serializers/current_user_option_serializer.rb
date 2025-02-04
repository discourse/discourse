# frozen_string_literal: true

class CurrentUserOptionSerializer < ApplicationSerializer
  attributes :mailing_list_mode,
             :external_links_in_new_tab,
             :enable_quoting,
             :enable_smart_lists,
             :dynamic_favicon,
             :automatically_unpin_topics,
             :likes_notifications_disabled,
             :hide_profile_and_presence,
             :hide_profile,
             :hide_presence,
             :title_count_mode,
             :enable_defer,
             :timezone,
             :skip_new_user_tips,
             :default_calendar,
             :bookmark_auto_delete_preference,
             :seen_popups,
             :should_be_redirected_to_top,
             :redirected_to_top,
             :treat_as_new_topic_start_date,
             :sidebar_link_to_filtered_list,
             :sidebar_show_count_of_new_items

  def likes_notifications_disabled
    object.likes_notifications_disabled?
  end

  def include_redirected_to_top?
    object.redirected_to_top.present?
  end

  def include_seen_popups?
    SiteSetting.enable_user_tips
  end
end
