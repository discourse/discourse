# frozen_string_literal: true

DiscourseEvent.on(:site_setting_changed) do |name, old_value, new_value|
  # Enabling `must_approve_users` on an existing site is odd, so we assume that the
  # existing users are approved.
  if name == :must_approve_users && new_value == true
    User.where(approved: false).update_all(approved: true)
  end

  if name == :emoji_set
    Emoji.clear_cache

    before = "/images/emoji/#{old_value}/"
    after = "/images/emoji/#{new_value}/"

    Scheduler::Defer.later("Fix Emoji Links") do
      DB.exec("UPDATE posts SET cooked = REPLACE(cooked, :before, :after) WHERE cooked LIKE :like",
        before: before,
        after: after,
        like: "%#{before}%"
      )
    end
  end

  Report.clear_cache(:storage_stats) if [:backup_location, :s3_backup_bucket].include?(name)

  if name == :slug_generation_method
    Scheduler::Defer.later("Null topic slug") do
      Topic.update_all(slug: nil)
    end
  end

  Jobs.enqueue(:update_s3_inventory) if [:enable_s3_inventory, :s3_upload_bucket].include?(name)

  Jobs.enqueue(:update_private_uploads_acl) if name == :prevent_anons_from_downloading_files

  SvgSprite.expire_cache if name.to_s.include?("_icon")

  if SiteIconManager::WATCHED_SETTINGS.include?(name)
    SiteIconManager.ensure_optimized!
  end

  if SiteSetting::WATCHED_SETTINGS.include?(name)
    SiteSetting.reset_cached_settings!
  end
end
