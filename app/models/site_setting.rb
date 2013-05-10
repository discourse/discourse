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
  setting(:contact_email, '')
  setting(:company_full_name, 'My Unconfigured Forum Ltd.')
  setting(:company_short_name, 'Unconfigured Forum')
  setting(:company_domain, 'www.example.com')
  setting(:tos_url, '')
  setting(:privacy_policy_url, '')
  setting(:api_key, '')
  client_setting(:traditional_markdown_linebreaks, false)
  client_setting(:top_menu, 'latest|new|unread|favorited|categories')
  client_setting(:post_menu, 'like|edit|flag|delete|share|bookmark|reply')
  client_setting(:share_links, 'twitter|facebook|google+|email')
  client_setting(:track_external_right_clicks, false)
  client_setting(:must_approve_users, false)
  client_setting(:ga_tracking_code, "")
  client_setting(:ga_domain_name, "")
  client_setting(:new_topics_rollup, 1)
  client_setting(:enable_long_polling, true)
  client_setting(:polling_interval, 3000)
  client_setting(:anon_polling_interval, 30000)
  client_setting(:min_post_length, Rails.env.test? ? 5 : 20)
  client_setting(:max_post_length, 16000)
  client_setting(:min_topic_title_length, 15)
  client_setting(:max_topic_title_length, 255)
  client_setting(:min_search_term_length, 3)
  client_setting(:flush_timings_secs, 5)
  client_setting(:supress_reply_directly_below, true)
  client_setting(:email_domains_blacklist, 'mailinator.com')
  client_setting(:email_domains_whitelist)
  client_setting(:version_checks, true)
  client_setting(:min_title_similar_length, 10)
  client_setting(:min_body_similar_length, 15)
  # cf. https://github.com/discourse/discourse/pull/462#issuecomment-14991562
  client_setting(:category_colors, 'BF1E2E|F1592A|F7941D|9EB83B|3AB54A|12A89D|25AAE2|0E76BD|652D90|92278F|ED207B|8C6238|231F20|808281|B3B5B4|283890')

  # auto-replace rules for title
  setting(:title_prettify, true)

  client_setting(:max_upload_size_kb, 1024)

  # settings only available server side
  setting(:auto_track_topics_after, 240000)
  setting(:new_topic_duration_minutes, 60 * 48)
  setting(:long_polling_interval, 15000)
  setting(:flags_required_to_hide_post, 3)
  setting(:cooldown_minutes_after_hiding_posts, 10)

  # used mainly for dev, force hostname for Discourse.base_url
  # You would usually use multisite for this
  setting(:force_hostname, '')
  setting(:port, Rails.env.development? ? 3000 : '')
  setting(:enable_private_messages, true)
  setting(:use_ssl, false)
  setting(:access_password)
  setting(:queue_jobs, !Rails.env.test?)
  setting(:crawl_images, !Rails.env.test?)
  setting(:enable_imgur, false)
  setting(:imgur_client_id, '')
  setting(:imgur_client_secret, '')
  setting(:imgur_endpoint, "http://api.imgur.com/3/image.json")
  setting(:max_image_width, 690)
  client_setting(:category_featured_topics, 6)
  setting(:topics_per_page, 30)
  setting(:posts_per_page, 20)
  setting(:invite_expiry_days, 14)
  setting(:active_user_rate_limit_secs, 60)
  setting(:previous_visit_timeout_hours, 1)
  setting(:favicon_url, '/assets/default-favicon.png')

  setting(:ninja_edit_window, 5.minutes.to_i)
  setting(:post_undo_action_window_mins, 10)
  setting(:system_username, '')
  setting(:max_mentions_per_post, 10)
  setting(:newuser_max_mentions_per_post, 2)

  client_setting(:uncategorized_name, 'uncategorized')
  client_setting(:uncategorized_color, 'AB9364');
  client_setting(:uncategorized_text_color, 'FFFFFF');

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
  setting(:auto_link_images_wider_than, 50)

  setting(:email_time_window_mins, 10)

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
  setting(:best_of_percent_filter, 20)

  # we need to think of a way to force users to enter certain settings, this is a minimal config thing
  setting(:notification_email, 'info@discourse.org')

  setting(:allow_index_in_robots_txt, true)

  setting(:send_welcome_message, true)

  client_setting(:enable_google_logins, true)
  client_setting(:enable_yahoo_logins, true)

  client_setting(:enable_twitter_logins, true)
  setting(:twitter_consumer_key, '')
  setting(:twitter_consumer_secret, '')

  client_setting(:enable_facebook_logins, true)
  setting(:facebook_app_id, '')
  setting(:facebook_app_secret, '')

  client_setting(:enable_github_logins, false)
  setting(:github_client_id, '')
  setting(:github_client_secret, '')

  client_setting(:enable_persona_logins, false)

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
  setting(:basic_requires_read_posts, 50)
  setting(:basic_requires_time_spent_mins, 15)

  setting(:regular_requires_topics_entered, 3)
  setting(:regular_requires_read_posts, 100)
  setting(:regular_requires_time_spent_mins, 60)
  setting(:regular_requires_days_visited, 15)
  setting(:regular_requires_likes_received, 1)
  setting(:regular_requires_likes_given, 1)
  setting(:regular_requires_topic_reply_count, 3)

  # Entropy checks
  setting(:title_min_entropy, 10)
  setting(:body_min_entropy, 7)
  setting(:max_word_length, 30)

  setting(:newuser_max_links, 2)
  setting(:newuser_max_images, 0)

  setting(:newuser_spam_host_threshold, 3)

  setting(:title_fancy_entities, true)

  # The default locale for the site
  setting(:default_locale, 'en')

  client_setting(:educate_until_posts, 2)

  setting(:max_similar_results, 7)

  # Settings for topic heat
  client_setting(:topic_views_heat_low,    1000)
  client_setting(:topic_views_heat_medium, 2000)
  client_setting(:topic_views_heat_high,   5000)

  def self.generate_api_key!
    self.api_key = SecureRandom.hex(32)
  end

  def self.api_key_valid?(tested)
    t = tested.strip
    t.length == 64 && t == self.api_key
  end

  def self.call_discourse_hub?
    self.enforce_global_nicknames? && self.discourse_org_access_key.present?
  end

  def self.topic_title_length
    min_topic_title_length..max_topic_title_length
  end

  def self.post_length
    min_post_length..max_post_length
  end

  def self.homepage
    top_menu.split('|')[0]
  end

  def self.anonymous_homepage
    top_menu.split('|').select{ |f| ['latest', 'hot', 'categories', 'category'].include? f }[0]
  end

end
