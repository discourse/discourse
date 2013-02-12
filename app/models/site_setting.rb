require 'site_setting_extension'

class SiteSetting < ActiveRecord::Base
  extend SiteSettingExtension

  validates_presence_of :name
  validates_presence_of :data_type

  attr_accessible :description, :name, :value, :data_type

  # settings available in javascript under Discourse.SiteSettings
  client_setting(:title, "Discourse")
  client_setting(:logo_url, '/assets/d-logo-sketch.png')
  client_setting(:logo_small_url, '/assets/d-logo-sketch-small.png')
  client_setting(:traditional_markdown_linebreaks, false)
  client_setting(:popup_delay, 1500)
  client_setting(:top_menu, 'popular|new|unread|favorited|categories')
  client_setting(:post_menu, 'like|edit|flag|delete|share|bookmark|reply')
  client_setting(:max_length_show_reply, 1500)
  client_setting(:track_external_right_clicks, false)
  client_setting(:must_approve_users, false)
  client_setting(:ga_tracking_code, "")
  client_setting(:new_topics_rollup, 1)
  client_setting(:enable_long_polling, true)
  client_setting(:polling_interval, 3000)
  client_setting(:anon_polling_interval, 30000)
  client_setting(:min_post_length, Rails.env.test? ? 5 : 20)
  client_setting(:max_post_length, 16000)
  client_setting(:min_topic_title_length, 5)
  client_setting(:max_topic_title_length, 255)
  client_setting(:flush_timings_secs, 5)
  client_setting(:supress_reply_directly_below, true)

  # settings only available server side
  setting(:auto_track_topics_after, 60000)
  setting(:long_polling_interval, 15000)
  setting(:flags_required_to_hide_post, 3)
  setting(:cooldown_minutes_after_hiding_posts, 10)

  # used mainly for dev, force hostname for Discourse.base_url
  # You would usually use multisite for this
  setting(:force_hostname, '')
  setting(:port, Rails.env.development? ? 3000 : '')
  setting(:enable_private_messages, true)
  setting(:use_ssl, false)
  setting(:secret_token)
  setting(:restrict_access, false)
  setting(:access_password)
  setting(:queue_jobs, !Rails.env.test?)
  setting(:crawl_images, !Rails.env.test?)
  setting(:enable_imgur, false)
  setting(:imgur_api_key, '')
  setting(:imgur_endpoint, "http://api.imgur.com/2/upload.json")
  setting(:max_image_width, 690)
  setting(:category_featured_topics, 6)
  setting(:topics_per_page, 30)
  setting(:posts_per_page, 20)
  setting(:invite_expiry_days, 14)
  setting(:active_user_rate_limit_secs, 60)
  setting(:previous_visit_timeout_hours, 1)
  setting(:favicon_url, '/assets/favicon.ico')

  setting(:ninja_edit_window, 5.minutes.to_i)
  setting(:post_undo_action_window_mins, 10)
  setting(:system_username, '')
  setting(:max_mentions_per_post, 5)

  setting(:uncategorized_name, 'uncategorized')

  setting(:unique_posts_mins, Rails.env.test? ? 0 : 5)

  # Rate Limits
  setting(:rate_limit_create_topic, 5)
  setting(:rate_limit_create_post, 5)
  setting(:max_topics_per_day, 20)
  setting(:max_private_messages_per_day, 20)
  setting(:max_likes_per_day, 30)
  setting(:max_bookmarks_per_day, 20)
  setting(:max_flags_per_day, 20)
  setting(:max_edits_per_day, 30)
  setting(:max_favorites_per_day, 20)


  setting(:email_time_window_mins, 5)

  # How many characters we can import into a onebox
  setting(:onebox_max_chars, 5000)

  setting(:suggested_topics, 5)

  setting(:allow_duplicate_topic_titles, false)

  setting(:add_rel_nofollow_to_user_content, true)
  setting(:exclude_rel_nofollow_domains, '')
  setting(:post_excerpt_maxlength, 300)
  setting(:post_onebox_maxlength, 500)
  setting(:best_of_score_threshold, 15)
  setting(:best_of_posts_required, 50)
  setting(:best_of_likes_required, 1)
  setting(:category_post_template,
          "[Replace this first paragraph with a short description of your new category. Try to keep it below 200 characters.]\n\nUse this space below for a longer description, as well as to establish any rules or discussion!")

  # we need to think of a way to force users to enter certain settings, this is a minimal config thing
  setting(:notification_email, 'info@discourse.org')

  setting(:allow_index_in_robots_txt, true)

  setting(:send_welcome_message, true)

  setting(:twitter_consumer_key, '')
  setting(:twitter_consumer_secret, '')

  setting(:facebook_app_id, '')
  setting(:facebook_app_secret, '')

  setting(:enforce_global_nicknames, true)
  setting(:discourse_org_access_key, '')
  setting(:enable_s3_uploads, false)
  setting(:s3_upload_bucket, '')

  setting(:default_trust_level, 0)
  setting(:default_invitee_trust_level, 1)

  # Import/Export settings
  setting(:allow_import, false)

  # Trust related
  setting(:basic_requires_topics_entered, 5)
  setting(:basic_requires_read_posts, 100)
  setting(:basic_requires_time_spent_mins, 30)

  # Entropy checks
  setting(:title_min_entropy, 10)
  setting(:body_min_entropy, 7)
  setting(:max_word_length, 30)

  # Ways to catch griefers and other nasties
  setting(:email_blacklist_regexp, '')



  def self.call_mothership?
    self.enforce_global_nicknames? and self.discourse_org_access_key.present?
  end

end
