# frozen_string_literal: true

module DiscourseAi
  module PostImageDescriptions
    DESCRIPTION_CLASS = "ai-image-description"
    DESCRIPTION_ID_PREFIX = "ai-image-description"
    ARIA_DESCRIPTION_ATTRIBUTE = "aria-description"
    LOOKUP_INDEX = "idx_ai_post_image_descriptions_lookup"
    REUSE_INDEX = "idx_ai_post_image_descriptions_reuse"
    MAX_ATTEMPTS = 3
    RETRY_AFTER = 1.day
    COOK_ENQUEUE_POST_MAX_AGE = 1.day
    BACKFILL_RUNS_PER_HOUR = 4
    SUPPORTED_EXTENSIONS = %w[jpg jpeg png gif webp].freeze
    MAX_DESCRIPTION_LENGTH = 1_000

    module_function

    def enabled?
      SiteSetting.discourse_ai_enabled && SiteSetting.ai_post_image_captions_enabled &&
        SiteSetting.ai_image_caption_agent.present?
    end

    def generation_enabled?
      return false if !enabled?

      agent = image_caption_agent
      return false if agent.blank? || !agent.enabled?

      llm_model = image_caption_llm_model(agent)

      agent.class_instance&.vision_enabled && llm_model&.vision_enabled?
    end

    def process_cooked(doc, post, locale:)
      remove_existing_description_metadata(doc)
      return if !enabled?
      return if !captionable_post?(post)

      base62_sha1s = image_base62_sha1s(doc, post_id: post.id)
      base62_sha1s = capped_base62_sha1s(base62_sha1s)

      delete_removed_descriptions(post, locale, base62_sha1s)

      return if base62_sha1s.blank?

      descriptions = descriptions_for(post.id, locale, base62_sha1s)
      exact_description_base62_sha1s = descriptions.keys
      descriptions = descriptions_with_locale_fallback(post, locale, base62_sha1s, descriptions)
      decorate(doc, descriptions:, locale:)
      enqueue_missing(
        post,
        locale: locale,
        base62_sha1s: base62_sha1s,
        existing_base62_sha1s: exact_description_base62_sha1s,
      )
    end

    def decorate(doc, descriptions:, locale:)
      return if descriptions.blank?

      image_nodes(doc).each do |img|
        base62_sha1 = image_node_base62_sha1(img)
        description = descriptions[base62_sha1]
        next if description.blank?

        aria_description = aria_description(description, locale)
        img[ARIA_DESCRIPTION_ATTRIBUTE] = aria_description
      end
    end

    def enqueue_missing(post, locale:, base62_sha1s:, existing_base62_sha1s: nil)
      return if base62_sha1s.blank?
      return if !generation_enabled?
      return if post.updated_at < COOK_ENQUEUE_POST_MAX_AGE.ago

      missing_base62_sha1s = pending_base62_sha1s(post.id, locale, base62_sha1s)
      missing_base62_sha1s -= existing_base62_sha1s if existing_base62_sha1s
      return if missing_base62_sha1s.blank?

      Jobs.enqueue(
        :generate_post_image_descriptions,
        post_id: post.id,
        locale: locale,
        base62_sha1s: missing_base62_sha1s,
      )
    end

    def generate_missing(post, locale:, base62_sha1s: nil)
      return 0 if !generation_enabled?
      return 0 if !captionable_post?(post)
      return 0 if !credits_available?

      current_base62_sha1s =
        image_base62_sha1s(Nokogiri::HTML5.fragment(post.cooked), post_id: post.id)
      current_base62_sha1s = capped_base62_sha1s(current_base62_sha1s)
      current_base62_sha1s &= base62_sha1s if base62_sha1s.present?
      if current_base62_sha1s.blank? && base62_sha1s.blank?
        record_uncaptionable_backfill_candidate(post, locale)
      end
      return 0 if current_base62_sha1s.blank?

      missing_base62_sha1s = pending_base62_sha1s(post.id, locale, current_base62_sha1s)
      return 0 if missing_base62_sha1s.blank?

      uploads_by_base62_sha1 = uploads_by_base62_sha1(missing_base62_sha1s)

      generated_count =
        reuse_descriptions(post, locale, missing_base62_sha1s, uploads_by_base62_sha1)
      missing_base62_sha1s = pending_base62_sha1s(post.id, locale, current_base62_sha1s)
      return 0 if generated_count == 0 && missing_base62_sha1s.blank?

      assistant = DiscourseAi::AiHelper::Assistant.new if missing_base62_sha1s.present?

      missing_base62_sha1s.each do |base62_sha1|
        upload = uploads_by_base62_sha1[base62_sha1]
        next if upload.blank?

        if !captionable_upload?(upload, post)
          record_attempt(post, upload, base62_sha1, locale, error: "upload_not_captionable")
          next
        end

        begin
          description =
            assistant.generate_image_caption(
              upload,
              Discourse.system_user,
              locale: locale,
              post: post,
              skip_access_check: true,
            )

          if description.blank?
            record_attempt(post, upload, base62_sha1, locale, error: "blank_response")
          else
            record_attempt(post, upload, base62_sha1, locale, description: description)
            generated_count += 1
          end
        rescue StandardError => e
          record_attempt(post, upload, base62_sha1, locale, error: e.message)
        end
      end

      return 0 if generated_count == 0

      SearchIndexer.index(post, force: true)
      refresh_cooked(post, locale)

      generated_count
    end

    def append_to_search_text(text, post_id, cooked, locale: SiteSetting.default_locale)
      return text if !enabled?
      return text if cooked.blank? || !cooked.include?("data-base62-sha1")

      locale = locale.presence || SiteSetting.default_locale

      base62_sha1s = image_base62_sha1s(Nokogiri::HTML5.fragment(cooked), post_id: post_id)
      base62_sha1s = capped_base62_sha1s(base62_sha1s)
      return text if base62_sha1s.blank?

      descriptions =
        AiPostImageDescription
          .where(post_id: post_id, locale: locale, base62_sha1: base62_sha1s)
          .where.not(description: nil)
          .distinct
          .pluck(:description)

      return text if descriptions.blank?

      "#{text} #{descriptions.join(" ")}"
    end

    def editable_descriptions(post, locale)
      return [] if !enabled?
      return [] if !captionable_post?(post)

      locale = locale.presence || original_locale(post)
      base62_sha1s = current_base62_sha1s(post)
      return [] if base62_sha1s.blank?

      descriptions = descriptions_for(post.id, locale, base62_sha1s)

      base62_sha1s.filter_map do |base62_sha1|
        description = descriptions[base62_sha1]
        next if description.blank?

        { base62_sha1: base62_sha1, description: description }
      end
    end

    def update_description(post, locale, base62_sha1, description)
      return if !enabled?
      return if !captionable_post?(post)
      return if !current_base62_sha1s(post).include?(base62_sha1)

      locale = locale.presence || original_locale(post)

      image_description =
        AiPostImageDescription.find_by(post_id: post.id, locale: locale, base62_sha1: base62_sha1)

      return if image_description.blank? || image_description.description.blank?

      image_description.update!(description: description, last_error: nil)
      SearchIndexer.index(post, force: true)
      refresh_cooked(post, locale)

      image_description
    end

    def backfill_limit
      hourly_rate = SiteSetting.ai_post_image_captions_backfill_hourly_rate.to_i
      return 0 if hourly_rate <= 0

      used_budget = DB.query_single(<<~SQL, threshold: 1.hour.ago).first.to_i
            SELECT COUNT(*)
            FROM (
              SELECT DISTINCT post_id, locale
              FROM ai_post_image_descriptions
              WHERE created_at > :threshold OR last_attempted_at > :threshold
            ) recent_targets
          SQL
      remaining_budget = hourly_rate - used_budget
      return 0 if remaining_budget <= 0

      per_run_limit = [hourly_rate / BACKFILL_RUNS_PER_HOUR, 1].max
      [per_run_limit, remaining_budget].min
    end

    def backfill_targets(limit:)
      return [] if limit.to_i <= 0

      connection = ActiveRecord::Base.connection
      default_locale = connection.quote(SiteSetting.default_locale)
      retry_after = connection.quote(RETRY_AFTER.ago)
      max_age_days = SiteSetting.ai_post_image_captions_backfill_max_age_days.to_i
      original_locale_sql = "COALESCE(NULLIF(posts.locale, ''), #{default_locale})"
      supported_extensions =
        SUPPORTED_EXTENSIONS.map { |extension| connection.quote(extension) }.join(", ")
      localized_targets_sql =
        if SiteSetting.content_localization_enabled
          <<~SQL
            UNION ALL

            SELECT posts.id AS post_id,
                   posts.image_upload_id AS upload_id,
                   post_localizations.locale AS locale
            FROM posts
            INNER JOIN topics ON topics.id = posts.topic_id
            INNER JOIN uploads ON uploads.id = posts.image_upload_id
            INNER JOIN post_localizations ON post_localizations.post_id = posts.id
            WHERE posts.post_type = #{Post.types[:regular]}
              AND posts.deleted_at IS NULL
              AND topics.deleted_at IS NULL
              AND topics.archetype <> #{connection.quote(Archetype.private_message)}
              AND posts.created_at > #{connection.quote(max_age_days.days.ago)}
              AND LOWER(uploads.extension) IN (#{supported_extensions})
              AND post_localizations.locale <> #{original_locale_sql}
          SQL
        else
          ""
        end

      DB
        .query(<<~SQL, limit: limit.to_i)
          WITH candidate_targets AS (
            SELECT posts.id AS post_id,
                   posts.image_upload_id AS upload_id,
                   #{original_locale_sql} AS locale
            FROM posts
            INNER JOIN topics ON topics.id = posts.topic_id
            INNER JOIN uploads ON uploads.id = posts.image_upload_id
            WHERE posts.post_type = #{Post.types[:regular]}
              AND posts.deleted_at IS NULL
              AND topics.deleted_at IS NULL
              AND topics.archetype <> #{connection.quote(Archetype.private_message)}
              AND posts.created_at > #{connection.quote(max_age_days.days.ago)}
              AND LOWER(uploads.extension) IN (#{supported_extensions})

            #{localized_targets_sql}
          )

          SELECT candidate_targets.post_id,
                 candidate_targets.locale
          FROM candidate_targets
          LEFT JOIN ai_post_image_descriptions existing_descriptions
            ON existing_descriptions.post_id = candidate_targets.post_id
            AND existing_descriptions.upload_id = candidate_targets.upload_id
            AND existing_descriptions.locale = candidate_targets.locale
            AND (
              existing_descriptions.description IS NOT NULL OR
              existing_descriptions.attempts >= #{MAX_ATTEMPTS} OR
              existing_descriptions.last_attempted_at > #{retry_after}
            )
          WHERE existing_descriptions.post_id IS NULL
            OR EXISTS (
              SELECT 1
              FROM ai_post_image_descriptions retryable_descriptions
              WHERE retryable_descriptions.post_id = candidate_targets.post_id
                AND retryable_descriptions.locale = candidate_targets.locale
                AND retryable_descriptions.description IS NULL
                AND retryable_descriptions.attempts < #{MAX_ATTEMPTS}
                AND (
                  retryable_descriptions.last_attempted_at IS NULL OR
                  retryable_descriptions.last_attempted_at <= #{retry_after}
                )
            )
          GROUP BY candidate_targets.post_id, candidate_targets.locale
          ORDER BY candidate_targets.post_id DESC, candidate_targets.locale
          LIMIT :limit
        SQL
        .map { |target| { post_id: target.post_id, locale: target.locale } }
    end

    def original_locale(post)
      post.locale.presence || SiteSetting.default_locale
    end

    def image_nodes(doc)
      nodes = doc.css("img[data-base62-sha1]")
      nodes -= doc.css(".quote img")
      nodes -= doc.css(".onebox img, .onebox-body img")
      nodes -= doc.css("img.avatar, img.emoji, img.site-icon, img.onebox-avatar")
      nodes -= doc.css("img.onebox-avatar-inline")
      nodes.select { |img| img["data-base62-sha1"].present? }
    end

    def image_base62_sha1s(doc, post_id: nil)
      sha1s_by_base62_sha1 =
        image_nodes(doc).each_with_object({}) do |img, result|
          base62_sha1 = image_node_base62_sha1(img)
          next if base62_sha1.blank?

          result[base62_sha1] = sha1_from_base62_sha1(base62_sha1)
        end

      return [] if sha1s_by_base62_sha1.blank?

      if post_id.present?
        post_upload_sha1s =
          Upload
            .joins(:upload_references)
            .where(sha1: sha1s_by_base62_sha1.values)
            .where(upload_references: { target_type: "Post", target_id: post_id })
            .pluck(:sha1)
            .to_set

        sha1s_by_base62_sha1.select! { |_, sha1| post_upload_sha1s.include?(sha1) }
      end

      sha1s_by_base62_sha1.keys
    end

    def descriptions_for(post_id, locale, base62_sha1s)
      AiPostImageDescription
        .where(post_id: post_id, locale: locale, base62_sha1: base62_sha1s)
        .where.not(description: nil)
        .pluck(:base62_sha1, :description)
        .to_h
    end

    def descriptions_with_locale_fallback(post, locale, base62_sha1s, descriptions)
      return descriptions if locale == original_locale(post)

      missing_base62_sha1s = base62_sha1s - descriptions.keys
      return descriptions if missing_base62_sha1s.blank?

      descriptions_for(post.id, original_locale(post), missing_base62_sha1s).merge(descriptions)
    end

    def capped_base62_sha1s(base62_sha1s)
      base62_sha1s.first(SiteSetting.ai_post_image_captions_per_post_limit.to_i)
    end

    def current_base62_sha1s(post)
      return [] if post.cooked.blank?

      base62_sha1s = image_base62_sha1s(Nokogiri::HTML5.fragment(post.cooked), post_id: post.id)
      capped_base62_sha1s(base62_sha1s)
    end

    def pending_base62_sha1s(post_id, locale, base62_sha1s)
      rows =
        AiPostImageDescription
          .where(post_id: post_id, locale: locale, base62_sha1: base62_sha1s)
          .pluck(:base62_sha1, :description, :attempts, :last_attempted_at)
          .index_by(&:first)

      base62_sha1s.select do |base62_sha1|
        row = rows[base62_sha1]
        row.blank? || retryable_row?(row)
      end
    end

    def retryable_row?(row)
      _, description, attempts, last_attempted_at = row
      return false if description.present?
      return false if attempts.to_i >= MAX_ATTEMPTS

      last_attempted_at.blank? || last_attempted_at <= RETRY_AFTER.ago
    end

    def uploads_by_base62_sha1(base62_sha1s)
      sha1s_by_base62_sha1 =
        base62_sha1s.each_with_object({}) do |base62_sha1, result|
          sha1 = sha1_from_base62_sha1(base62_sha1)
          result[base62_sha1] = sha1 if sha1.present?
        end

      uploads_by_sha1 = Upload.where(sha1: sha1s_by_base62_sha1.values).index_by(&:sha1)

      sha1s_by_base62_sha1.transform_values { |sha1| uploads_by_sha1[sha1] }.compact
    end

    def reuse_descriptions(post, locale, base62_sha1s, uploads_by_base62_sha1)
      reusable_descriptions = reusable_descriptions_for(post.id, locale, base62_sha1s)
      return 0 if reusable_descriptions.blank?

      reused_count = 0

      reusable_descriptions.each do |base62_sha1, description|
        upload = uploads_by_base62_sha1[base62_sha1]
        next if upload.blank? || !captionable_upload?(upload, post)

        record_reused_description(post, upload, base62_sha1, locale, description)
        reused_count += 1
      end

      reused_count
    end

    def reusable_descriptions_for(post_id, locale, base62_sha1s)
      DB
        .query(<<~SQL, post_id: post_id, locale: locale, base62_sha1s: base62_sha1s)
            SELECT DISTINCT ON (base62_sha1) base62_sha1, description
            FROM ai_post_image_descriptions
            WHERE locale = :locale
              AND base62_sha1 IN (:base62_sha1s)
              AND post_id <> :post_id
              AND description IS NOT NULL
            ORDER BY base62_sha1, updated_at DESC, id DESC
          SQL
        .map { |row| [row.base62_sha1, row.description] }
        .to_h
    end

    def captionable_upload?(upload, post)
      return false if upload.blank?
      return false if !SUPPORTED_EXTENSIONS.include?(upload.extension.to_s.downcase)
      return false if upload.secure? && upload.access_control_post_id != post.id

      true
    end

    def captionable_post?(post)
      post.present? && post.raw.present? && post.deleted_at.blank? && post.topic.present? &&
        post.topic.deleted_at.blank? && post.post_type == Post.types[:regular] &&
        !post.topic.private_message?
    end

    def record_uncaptionable_backfill_candidate(post, locale)
      upload = Upload.find_by(id: post.image_upload_id)
      return if upload.blank?

      record_attempt(post, upload, upload.base62_sha1, locale, error: "no_post_image_nodes")
    end

    def record_attempt(post, upload, base62_sha1, locale, description: nil, error: nil)
      now = Time.zone.now

      DB.exec(
        <<~SQL,
          INSERT INTO ai_post_image_descriptions
            (
              post_id,
              upload_id,
              base62_sha1,
              locale,
              description,
              attempts,
              last_attempted_at,
              last_error,
              created_at,
              updated_at
            )
          VALUES
            (
              :post_id,
              :upload_id,
              :base62_sha1,
              :locale,
              :description,
              1,
              :now,
              :last_error,
              :now,
              :now
            )
          ON CONFLICT (post_id, locale, base62_sha1) DO UPDATE SET
            upload_id = EXCLUDED.upload_id,
            description = EXCLUDED.description,
            attempts = ai_post_image_descriptions.attempts + 1,
            last_attempted_at = EXCLUDED.last_attempted_at,
            last_error = EXCLUDED.last_error,
            updated_at = EXCLUDED.updated_at
        SQL
        post_id: post.id,
        upload_id: upload.id,
        base62_sha1: base62_sha1,
        locale: locale,
        description: description,
        last_error: error,
        now: now,
      )
    end

    def record_reused_description(post, upload, base62_sha1, locale, description)
      now = Time.zone.now

      DB.exec(
        <<~SQL,
          INSERT INTO ai_post_image_descriptions
            (
              post_id,
              upload_id,
              base62_sha1,
              locale,
              description,
              attempts,
              created_at,
              updated_at
            )
          VALUES
            (
              :post_id,
              :upload_id,
              :base62_sha1,
              :locale,
              :description,
              0,
              :now,
              :now
            )
          ON CONFLICT (post_id, locale, base62_sha1) DO UPDATE SET
            upload_id = EXCLUDED.upload_id,
            description = EXCLUDED.description,
            attempts = 0,
            last_attempted_at = NULL,
            last_error = NULL,
            updated_at = EXCLUDED.updated_at
        SQL
        post_id: post.id,
        upload_id: upload.id,
        base62_sha1: base62_sha1,
        locale: locale,
        description: description,
        now: now,
      )
    end

    def image_caption_agent
      AiAgent.find_by(id: SiteSetting.ai_image_caption_agent.to_i)
    end

    def image_caption_llm_model(agent = image_caption_agent)
      return if agent.blank?

      DiscourseAi::AiHelper::Assistant.find_ai_helper_model(
        DiscourseAi::AiHelper::Assistant::IMAGE_CAPTION,
        agent.class_instance,
      )
    end

    def credits_available?
      LlmCreditAllocation.credits_available?(image_caption_llm_model)
    end

    def delete_for_post(post_id)
      AiPostImageDescription.where(post_id: post_id).delete_all
    end

    def aria_description(description, locale)
      I18n.with_locale(locale) do
        I18n.t("discourse_ai.ai_helper.image_caption.aria_description", description: description)
      end
    end

    def image_node_base62_sha1(img)
      base62_sha1 = img["data-base62-sha1"]
      sha1 = sha1_from_base62_sha1(base62_sha1)
      return if sha1.blank?
      return if image_node_upload_sha1(img) != sha1

      base62_sha1
    end

    def sha1_from_base62_sha1(base62_sha1)
      return if base62_sha1.blank?
      return if base62_sha1.length > Upload::MAX_BASE62_SHA1_LENGTH
      return if !base62_sha1.match?(/\A[0-9a-zA-Z]+\z/)

      Upload.sha1_from_base62_encoded(base62_sha1)
    end

    def image_node_upload_sha1(img)
      src = img["src"].to_s

      if src.end_with?("/images/transparent.png") && img["data-orig-src"].present?
        src = img["data-orig-src"]
      end

      return Upload.sha1_from_short_url(src) if src.start_with?("upload://")

      path =
        begin
          URI(UrlHelper.unencode(src))&.path
        rescue URI::Error
          src
        end

      return if path.blank?

      OptimizedImage.extract_sha1(path) || Upload.extract_sha1(path) ||
        Upload.sha1_from_short_path(path)
    end

    def delete_removed_descriptions(post, locale, base62_sha1s)
      scope = AiPostImageDescription.where(post_id: post.id)
      scope = scope.where(locale: locale) if locale != original_locale(post)
      scope = scope.where.not(base62_sha1: base62_sha1s) if base62_sha1s.present?
      scope.delete_all
    end

    def remove_existing_description_metadata(doc)
      doc.css("span.#{DESCRIPTION_CLASS}").remove

      doc.css("[aria-describedby]").each { |node| remove_ai_describedby(node) }

      doc
        .css("img[data-base62-sha1][#{ARIA_DESCRIPTION_ATTRIBUTE}]")
        .each do |img|
          lightbox = img.ancestors("a.lightbox").first

          img.remove_attribute(ARIA_DESCRIPTION_ATTRIBUTE)
          lightbox.remove_attribute(ARIA_DESCRIPTION_ATTRIBUTE) if lightbox
        end
    end

    def remove_ai_describedby(node)
      ids =
        node["aria-describedby"].to_s.split.reject { |id| id.start_with?(DESCRIPTION_ID_PREFIX) }

      if ids.present?
        node["aria-describedby"] = ids.join(" ")
      else
        node.remove_attribute("aria-describedby")
      end
    end

    def refresh_cooked(post, locale)
      if locale == original_locale(post)
        post.rebake!(skip_publish_rebaked_changes: true)
      else
        PostLocalization
          .where(post_id: post.id, locale: locale)
          .pluck(:id)
          .each do |post_localization_id|
            Jobs.enqueue(
              :process_localized_cooked,
              post_localization_id: post_localization_id,
              recook: true,
            )
          end
      end
    end
  end
end
