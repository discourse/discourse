# Enabling `must_approve_users` on an existing site is odd, so we assume that the
# existing users are approved.
DiscourseEvent.on(:site_setting_saved) do |site_setting|
  name = site_setting.name.to_sym
  next unless site_setting.value_changed?

  if name == :must_approve_users && site_setting.value == 't'
    User.where(approved: false).update_all(approved: true)
  end

  if name == :emoji_set
    Emoji.clear_cache

    previous_value = site_setting.attribute_in_database(:value) || SiteSetting.defaults[:emoji_set]
    before = "/images/emoji/#{previous_value}/"
    after = "/images/emoji/#{site_setting.value}/"

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

  Jobs.enqueue(:update_s3_inventory) if [:s3_inventory, :s3_upload_bucket].include?(name)

  SvgSprite.expire_cache if name.to_s.include?("_icon")
end
