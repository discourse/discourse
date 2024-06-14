# frozen_string_literal: true

PRIVATE_BOOTSTRAP_MODE_MIN_USERS = 10

DiscourseEvent.on(:site_setting_changed) do |name, old_value, new_value|
  Category.clear_subcategory_ids if name === :max_category_nesting

  # Enabling `must_approve_users` on an existing site is odd, so we assume that the
  # existing users are approved.
  if name == :must_approve_users && new_value == true
    User
      .where(approved: false)
      .joins("LEFT JOIN reviewables r ON r.target_id = users.id")
      .where(r: { id: nil })
      .update_all(approved: true)
  end

  if name == :emoji_set
    Emoji.clear_cache

    before = "/images/emoji/#{old_value}/"
    after = "/images/emoji/#{new_value}/"

    Scheduler::Defer.later("Fix Emoji Links") do
      DB.exec(
        "UPDATE posts SET cooked = REPLACE(cooked, :before, :after) WHERE cooked LIKE :like",
        before: before,
        after: after,
        like: "%#{before}%",
      )
    end
  end

  # Set bootstrap min users for private sites to a lower default
  if name == :login_required && SiteSetting.bootstrap_mode_enabled == true
    if new_value == true &&
         SiteSetting.bootstrap_mode_min_users == SiteSetting.defaults.get(:bootstrap_mode_min_users)
      SiteSetting.bootstrap_mode_min_users = PRIVATE_BOOTSTRAP_MODE_MIN_USERS
    end

    # Set bootstrap min users for public sites back to the default
    if new_value == false &&
         SiteSetting.bootstrap_mode_min_users == PRIVATE_BOOTSTRAP_MODE_MIN_USERS
      SiteSetting.bootstrap_mode_min_users = SiteSetting.defaults.get(:bootstrap_mode_min_users)
    end
  end

  Stylesheet::Manager.clear_color_scheme_cache! if %i[base_font heading_font].include?(name)

  Report.clear_cache(:storage_stats) if %i[backup_location s3_backup_bucket].include?(name)

  if name == :slug_generation_method
    Scheduler::Defer.later("Null topic slug") { Topic.update_all(slug: nil) }
  end

  SvgSprite.expire_cache if name.to_s.include?("_icon")

  SiteIconManager.ensure_optimized! if SiteIconManager::WATCHED_SETTINGS.include?(name)

  # Make sure medium and high priority thresholds were calculated.
  if name == :reviewable_low_priority_threshold && Reviewable.min_score_for_priority(:medium) > 0
    Reviewable.set_priorities(low: new_value)
  end

  Emoji.clear_cache && Discourse.request_refresh! if name == :emoji_deny_list

  Discourse.clear_urls! if %i[tos_topic_id privacy_topic_id].include?(name)

  # Update seeded topics
  if %i[title site_description].include?(name)
    topics = SeedData::Topics.with_default_locale
    topics.update(site_setting_names: ["welcome_topic_id"], skip_changed: true)
  elsif %i[company_name contact_email governing_law city_for_disputes].include?(name)
    topics = SeedData::Topics.with_default_locale
    %w[tos_topic_id privacy_topic_id].each do |site_setting|
      topic_id = SiteSetting.get(site_setting)
      if topic_id > 0 && Topic.with_deleted.exists?(id: topic_id)
        if SiteSetting.company_name.blank?
          topics.delete(site_setting_names: [site_setting], skip_changed: true)
        else
          topics.update(site_setting_names: [site_setting], skip_changed: true)
        end
      elsif SiteSetting.company_name.present?
        topics.create(site_setting_names: [site_setting])
      end
    end
  end
end
