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

  Theme.expire_site_cache! if name == :default_theme_id

  if name == :splash_screen_image && new_value.present?
    upload = Upload.find_by(id: new_value)

    if upload&.extension == "svg"
      content =
        begin
          upload.content
        rescue StandardError
          nil
        end

      if content.present?
        doc = Nokogiri.XML(content)
        svg = doc.at_css("svg")

        if svg.present?
          has_scripts = svg.xpath("//script").present?
          has_event_handlers = svg.xpath("//@*[starts-with(name(), 'on')]").present?

          if has_scripts || has_event_handlers
            SiteSetting.set("splash_screen_image", "")
          else
            svg.xpath(
              ".//*[local-name()='animate' or local-name()='animateTransform' or local-name()='animateMotion' or local-name()='set']",
            ).each(&:remove)

            # Remove explicit dimensions so the SVG scales via viewBox
            if svg["viewBox"].present?
              svg.remove_attribute("width")
              svg.remove_attribute("height")
            end

            cleaned_svg = svg.to_xml

            if cleaned_svg != content
              Tempfile.open(%w[splash_screen .svg]) do |tmp|
                tmp.write(cleaned_svg)
                tmp.rewind

                new_sha1 = Upload.generate_digest(tmp.path)
                existing = Upload.find_by(sha1: new_sha1)

                if existing && existing.id != upload.id
                  SiteSetting.set("splash_screen_image", existing.id)
                else
                  old_path = Discourse.store.get_path_for_upload(upload)
                  old_url = upload.url
                  upload.sha1 = new_sha1
                  upload.filesize = tmp.size
                  upload.url = Discourse.store.store_upload(tmp, upload)
                  upload.save!(validate: false)

                  Discourse.store.remove_file(old_url, old_path) if upload.url != old_url
                end
              end
            end
          end
        end
      end

      Discourse.cache.delete("splash_screen_svg_#{upload.id}_#{upload.sha1}")
    end
  end

  if name == :content_localization_enabled && new_value == true
    %i[post_menu post_menu_hidden_items].each do |setting_name|
      current_items = SiteSetting.get(setting_name).split("|")
      if current_items.exclude?("addTranslation")
        edit_index = current_items.index("edit")
        insert_position = edit_index ? edit_index + 1 : 0
        current_items.insert(insert_position, "addTranslation")
        SiteSetting.set(setting_name, current_items.join("|"))
      end
    end
  end

  # Update Discourse ID metadata
  if SiteSetting.discourse_id_client_id.present? && SiteSetting.discourse_id_client_secret.present?
    if %i[title logo logo_small site_description].include?(name)
      Scheduler::Defer.later("Update Discourse ID metadata") do
        begin
          DiscourseId::Register.call(update: true)
        rescue StandardError => e
          Rails.logger.error(
            "Failed to update Discourse ID metadata after #{name} change: #{e.message}",
          )
        end
      end
    end
  end
end
