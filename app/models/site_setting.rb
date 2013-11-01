require 'site_setting_extension'

class SiteSetting < ActiveRecord::Base
  extend SiteSettingExtension

  validates_presence_of :name
  validates_presence_of :data_type

  # settings available in javascript under Discourse.SiteSettings
  client_setting(:title, "Discourse")
  setting(:site_description, '')
  client_setting(:logo_url, '/assets/d-logo-sketch.png')
  client_setting(:logo_small_url, '/assets/d-logo-sketch-small.png')
  setting(:contact_email, '')
  setting(:company_full_name, 'My Unconfigured Forum Ltd.')
  setting(:company_short_name, 'Unconfigured Forum')
  setting(:company_domain, 'www.example.com')
  client_setting(:tos_url, '')
  client_setting(:faq_url, '')
  client_setting(:privacy_policy_url, '')
  client_setting(:traditional_markdown_linebreaks, false)
  client_setting(:top_menu, 'latest|new|unread|favorited|categories')
  client_setting(:post_menu, 'like|edit|flag|delete|share|bookmark|reply')
  client_setting(:share_links, 'twitter|facebook|google+|email')
  client_setting(:track_external_right_clicks, false)
  client_setting(:must_approve_users, false)
  client_setting(:ga_tracking_code, "")
  client_setting(:ga_domain_name, "")
  client_setting(:enable_escaped_fragments, false)
  client_setting(:enable_noscript_support, true)
  client_setting(:enable_long_polling, true)
  client_setting(:polling_interval, 3000)
  client_setting(:anon_polling_interval, 30000)
  client_setting(:min_post_length, Rails.env.test? ? 5 : 20)
  client_setting(:min_private_message_post_length, Rails.env.test? ? 5 : 10)
  client_setting(:max_post_length, 32000)
  client_setting(:min_topic_title_length, 15)
  client_setting(:max_topic_title_length, 255)
  client_setting(:min_private_message_title_length, 2)
  client_setting(:allow_uncategorized_topics, true)
  client_setting(:min_search_term_length, 3)
  client_setting(:flush_timings_secs, 5)
  client_setting(:suppress_reply_directly_below, true)
  client_setting(:suppress_reply_directly_above, true)
  client_setting(:email_domains_blacklist, 'mailinator.com')
  client_setting(:email_domains_whitelist)
  client_setting(:version_checks, true)
  setting(:new_version_emails, true)
  client_setting(:min_title_similar_length, 10)
  client_setting(:min_body_similar_length, 15)
  # cf. https://github.com/discourse/discourse/pull/462#issuecomment-14991562
  client_setting(:category_colors, 'BF1E2E|F1592A|F7941D|9EB83B|3AB54A|12A89D|25AAE2|0E76BD|652D90|92278F|ED207B|8C6238|231F20|808281|B3B5B4|283890')
  client_setting(:enable_wide_category_list, false)

  # auto-replace rules for title
  setting(:title_prettify, true)

  client_setting(:max_image_size_kb, 2048)
  client_setting(:max_attachment_size_kb, 1024)
  client_setting(:authorized_extensions, '.jpg|.jpeg|.png|.gif')

  # settings only available server side
  setting(:auto_track_topics_after, 240000)
  setting(:new_topic_duration_minutes, 60 * 48)
  setting(:long_polling_interval, 15000)
  setting(:flags_required_to_hide_post, 3)
  setting(:cooldown_minutes_after_hiding_posts, 10)

  setting(:max_topics_in_first_day, 5)
  setting(:max_replies_in_first_day, 10)

  setting(:num_flags_to_block_new_user, 3)
  setting(:num_users_to_block_new_user, 3)
  setting(:notify_mods_when_user_blocked, false)

  setting(:flag_sockpuppets, true)

  # used mainly for dev, force hostname for Discourse.base_url
  # You would usually use multisite for this
  setting(:force_hostname, '')
  setting(:port, Rails.env.development? ? 3000 : '')
  setting(:enable_private_messages, true)
  setting(:use_ssl, false)
  setting(:queue_jobs, !Rails.env.test?)
  setting(:crawl_images, !Rails.env.test?)
  client_setting(:max_image_width, 690)
  client_setting(:max_image_height, 500)
  setting(:create_thumbnails, true)
  client_setting(:category_featured_topics, 6)
  setting(:topics_per_page, 30)
  client_setting(:posts_per_page, 20)
  setting(:invite_expiry_days, 14)
  setting(:active_user_rate_limit_secs, 60)
  setting(:previous_visit_timeout_hours, 1)
  client_setting(:favicon_url, '/assets/default-favicon.ico')
  setting(:apple_touch_icon_url, '/assets/default-apple-touch-icon.png')

  setting(:ninja_edit_window, 5.minutes.to_i)
  client_setting(:edit_history_visible_to_public, true)
  client_setting(:delete_removed_posts_after, 24) # hours
  setting(:post_undo_action_window_mins, 10)
  setting(:site_contact_username, '')
  setting(:max_mentions_per_post, 10)
  setting(:newuser_max_mentions_per_post, 2)

  setting(:unique_posts_mins, Rails.env.test? ? 0 : 5)

  # Rate Limits
  setting(:rate_limit_create_topic, 5)
  setting(:rate_limit_create_post, 5)
  setting(:max_topics_per_day, 20)
  setting(:max_private_messages_per_day, 20)
  setting(:max_likes_per_day, 50)
  setting(:max_bookmarks_per_day, 20)
  setting(:max_flags_per_day, 20)
  setting(:max_edits_per_day, 30)
  setting(:max_favorites_per_day, 20)

  setting(:email_time_window_mins, 10)
  setting(:email_posts_context, 5)
  setting(:default_digest_email_frequency, '7', enum: 'DigestEmailSiteSetting')

  # How many characters we can import into a onebox
  setting(:onebox_max_chars, 5000)

  setting(:suggested_topics, 5)

  setting(:allow_duplicate_topic_titles, false)

  setting(:staff_like_weight, 3)

  setting(:add_rel_nofollow_to_user_content, true)
  setting(:exclude_rel_nofollow_domains, '')
  setting(:post_excerpt_maxlength, 300)
  setting(:post_onebox_maxlength, 500)
  setting(:best_of_score_threshold, 15)
  setting(:best_of_posts_required, 50)
  setting(:best_of_likes_required, 1)
  setting(:best_of_percent_filter, 20)

  # we need to think of a way to force users to enter certain settings, this is a minimal config thing
  setting(:notification_email, 'info@discourse.org')
  setting(:email_custom_headers, 'Auto-Submitted: auto-generated')

  setting(:allow_index_in_robots_txt, true)

  setting(:send_welcome_message, true)

  client_setting(:invite_only, false)

  client_setting(:login_required, false)

  client_setting(:enable_local_logins, true)
  client_setting(:enable_local_account_create, true)

  client_setting(:enable_google_logins, true)
  client_setting(:enable_yahoo_logins, true)

  client_setting(:enable_twitter_logins, true)
  setting(:twitter_consumer_key, '')
  setting(:twitter_consumer_secret, '')

  # note we set this (and twitter to true for 2 reasons)
  # 1. its an upgrade nightmare to change it to false, lots of people will complain
  # 2. it advertises the feature (even though it is broken)
  client_setting(:enable_facebook_logins, true)
  setting(:facebook_app_id, '')
  setting(:facebook_app_secret, '')

  client_setting(:enable_cas_logins, false)
  setting(:cas_hostname, '')
  setting(:cas_domainname, '')

  client_setting(:enable_github_logins, false)
  setting(:github_client_id, '')
  setting(:github_client_secret, '')

  client_setting(:enable_persona_logins, false)

  setting(:enforce_global_nicknames, true)
  setting(:discourse_org_access_key, '')

  setting(:clean_up_uploads, false)
  setting(:uploads_grace_period_in_hours, 1)
  setting(:enable_s3_uploads, false)
  setting(:s3_access_key_id, '')
  setting(:s3_secret_access_key, '')
  setting(:s3_region, '', enum: 'S3RegionSiteSetting')
  setting(:s3_upload_bucket, '')

  setting(:enable_flash_video_onebox, false)

  setting(:default_trust_level, 0)
  setting(:default_invitee_trust_level, 1)

  # Import/Export settings
  setting(:allow_import, false)

  # Trust related
  setting(:basic_requires_topics_entered, 5)
  setting(:basic_requires_read_posts, 50)
  setting(:basic_requires_time_spent_mins, 15)

  setting(:regular_requires_topics_entered, 20)
  setting(:regular_requires_read_posts, 100)
  setting(:regular_requires_time_spent_mins, 60)
  setting(:regular_requires_days_visited, 15)
  setting(:regular_requires_likes_received, 1)
  setting(:regular_requires_likes_given, 1)
  setting(:regular_requires_topic_reply_count, 3)

  setting(:min_trust_to_create_topic, 0, enum: 'MinTrustToCreateTopicSetting')

  # Reply by Email Settings
  setting(:reply_by_email_enabled, false)
  setting(:reply_by_email_address, '')

  setting(:pop3s_polling_enabled, false)
  setting(:pop3s_polling_host, '')
  setting(:pop3s_polling_port, 995)
  setting(:pop3s_polling_username, '')
  setting(:pop3s_polling_password, '')

  # Entropy checks
  setting(:title_min_entropy, 10)
  setting(:body_min_entropy, 7)
  setting(:max_word_length, 30)

  setting(:newuser_max_links, 2)
  client_setting(:newuser_max_images, 0)
  client_setting(:newuser_max_attachments, 0)

  setting(:newuser_spam_host_threshold, 3)

  setting(:title_fancy_entities, true)

  # The default locale for the site
  setting(:default_locale, 'en', enum: 'LocaleSiteSetting')

  client_setting(:educate_until_posts, 2)

  setting(:max_similar_results, 7)

  # Settings for topic heat
  client_setting(:topic_views_heat_low,    1000)
  client_setting(:topic_views_heat_medium, 2000)
  client_setting(:topic_views_heat_high,   5000)

  setting(:minimum_topics_similar, 50)

  client_setting(:relative_date_duration, 30)

  client_setting(:delete_user_max_age, 14)
  setting(:delete_all_posts_max, 15)

  setting(:username_change_period, 3) # days
  setting(:email_editable, true)

  client_setting(:allow_uploaded_avatars, true)
  client_setting(:allow_animated_avatars, false)

  setting(:detect_custom_avatars, true)
  setting(:max_daily_gravatar_crawls, 500)

  setting(:sequential_replies_threshold, 2)
  client_setting(:enable_mobile_theme, true)

  setting(:dominating_topic_minimum_percent, 20)

  # hidden setting only used by system
  setting(:uncategorized_category_id, -1, hidden: true)

  client_setting(:display_name_on_posts, false)
  client_setting(:enable_names, true)

  def self.call_discourse_hub?
    self.enforce_global_nicknames? && self.discourse_org_access_key.present?
  end

  def self.topic_title_length
    min_topic_title_length..max_topic_title_length
  end

  def self.private_message_title_length
    min_private_message_title_length..max_topic_title_length
  end

  def self.post_length
    min_post_length..max_post_length
  end

  def self.private_message_post_length
    min_private_message_post_length..max_post_length
  end

  def self.top_menu_items
    top_menu.split('|').map { |menu_item| TopMenuItem.new(menu_item) }
  end

  def self.homepage
    top_menu_items[0].name
  end

  def self.anonymous_menu_items
    @anonymous_menu_items ||= Set.new ['latest', 'hot', 'categories', 'category']
  end

  def self.anonymous_homepage
    top_menu_items.map { |item| item.name }
                  .select { |item| anonymous_menu_items.include?(item) }
                  .first
  end

  def self.authorized_uploads
    authorized_extensions.tr(" ", "")
                         .split("|")
                         .map { |extension| (extension.start_with?(".") ? extension[1..-1] : extension).gsub(".", "\.") }
  end

  def self.authorized_upload?(file)
    authorized_uploads.count > 0 && file.original_filename =~ /\.(#{authorized_uploads.join("|")})$/i
  end

  def self.images
    @images ||= Set.new ["jpg", "jpeg", "png", "gif", "tif", "tiff", "bmp"]
  end

  def self.authorized_images
    authorized_uploads.select { |extension| images.include?(extension) }
  end

  def self.authorized_image?(file)
    authorized_images.count > 0 && file.original_filename =~ /\.(#{authorized_images.join("|")})$/i
  end

end

# == Schema Information
#
# Table name: site_settings
#
#  id         :integer          not null, primary key
#  name       :string(255)      not null
#  data_type  :integer          not null
#  value      :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

