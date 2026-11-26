# frozen_string_literal: true

module BulkImport::DiscourseMerge
  # Only full planning needs these rows. Keep password material, profile answers
  # (apart from option labels), and translated bodies out of the inventory.
  module ContentInventory
    BOTH = {
      "user_fields" =>
        "SELECT f.*, EXISTS (SELECT FROM directory_columns d WHERE d.user_field_id=f.id AND d.enabled) AS listed FROM user_fields f",
      "user_field_options" => "SELECT id,user_field_id,value FROM user_field_options",
      "published_pages" => "SELECT id,slug,topic_id,public FROM published_pages",
      "permalinks" => "SELECT * FROM permalinks",
      "custom_emojis" =>
        "SELECT e.id,e.name,e.upload_id,e.user_id,u.sha1,u.url FROM custom_emojis e LEFT JOIN uploads u ON u.id=e.upload_id",
      "category_moderation_groups" =>
        "SELECT id,category_id,group_id FROM category_moderation_groups",
      "tags" => "SELECT id,name,slug FROM tags",
      "category_localizations" => "SELECT id,category_id,locale FROM category_localizations",
      "tag_localizations" => "SELECT id,tag_id,locale FROM tag_localizations",
    }.freeze

    SOURCE = {
      "user_passwords" => <<~SQL,
        SELECT p.id,p.user_id,p.password_algorithm,
          EXISTS (SELECT FROM user_security_keys k WHERE k.user_id=p.user_id AND k.enabled) AS security_key,
          EXISTS (SELECT FROM user_second_factors f WHERE f.user_id=p.user_id AND f.enabled AND f.method=1) AS totp
        FROM user_passwords p
      SQL
      "user_custom_fields" => <<~SQL,
        SELECT c.id,c.user_id,c.name, CASE WHEN f.field_type_enum IN (2,3) THEN c.value END AS choice
        FROM user_custom_fields c LEFT JOIN user_fields f ON c.name='user_field_' || f.id
        WHERE c.name ~ '^user_field_[0-9]+$'
      SQL
      "allowed_pm_users" => "SELECT id,user_id,allowed_pm_user_id FROM allowed_pm_users",
      "shared_drafts" => "SELECT id,category_id,topic_id FROM shared_drafts",
      "post_localizations" =>
        "SELECT l.id,l.post_id,p.topic_id,l.localizer_user_id,l.locale FROM post_localizations l LEFT JOIN posts p ON p.id=l.post_id",
      "topic_localizations" =>
        "SELECT id,topic_id,localizer_user_id,locale FROM topic_localizations",
    }.freeze

    def self.destination_settings
      {
        "local_passwords" =>
          SiteSetting.enable_local_logins && !SiteSetting.enable_discourse_connect,
        "moderation" => SiteSetting.enable_category_group_moderation,
        "draft_category" => SiteSetting.shared_drafts_category.to_i,
        "draft_groups" => SiteSetting.shared_drafts_allowed_groups_map.sort,
        "admin_bypass" => !SiteSetting.suppress_secured_categories_from_admin,
        "publishing" => SiteSetting.enable_page_publishing && !SiteSetting.secure_uploads,
        "anonymous_publishing" =>
          !SiteSetting.login_required || SiteSetting.show_published_pages_login_required,
      }
    end

    def self.capture(connection, side, result, configuration)
      queries = side == "source" ? BOTH.merge(SOURCE) : BOTH
      data =
        queries.to_h do |table, query|
          [table, connection.exec("SELECT * FROM (#{query}) inventory ORDER BY id").to_a]
        end
      data["authorities"] = connection.exec(
        "SELECT id,trust_level,admin,moderator FROM users WHERE id>0 ORDER BY id",
      ).to_a if side == "source"
      data["email_access_categories"] = connection
        .exec(
          "SELECT id FROM categories WHERE read_restricted AND email_in_allow_strangers AND nullif(email_in, '') IS NOT NULL ORDER BY id",
        )
        .column_values(0)
        .map(&:to_i)
      data["admins"] = connection
        .exec("SELECT id FROM users WHERE id>0 AND admin ORDER BY id")
        .column_values(0)
        .map(&:to_i)
      if side == "source"
        data["source_settings"] = connection.exec(<<~SQL).values.to_h
          SELECT name,value FROM site_settings WHERE name IN ('shared_drafts_category','shared_drafts_allowed_groups','enable_page_publishing','secure_uploads','show_published_pages_login_required','suppress_secured_categories_from_admin','granular_anonymous_and_logged_in_groups_permissions')
        SQL
        data["historical_users"] = connection.exec(
          "SELECT id FROM users WHERE id < -2 ORDER BY id",
        ).column_values(0)
        data["permalinks"].each do |row|
          resolve_source_link(connection, row, configuration) if row["external_url"]
        end
        # Follow literal aliases on the source without installing its site-wide normalization rules.
        aliases = data.fetch("permalinks").index_by { |r| r.fetch("url") }
        data
          .fetch("permalinks")
          .each do |r|
            next unless r["source_path"]
            target = r
            seen = Set.new
            while target && target["source_path"] && seen.add?(target["id"])
              target = aliases[target["source_path"]]
            end
            if target && !target["unresolved"]
              r.merge!(
                target.slice(
                  "topic_id",
                  "post_id",
                  "category_id",
                  "tag_id",
                  "user_id",
                  "external_url",
                ),
              )
              r.delete("unresolved")
            end
          end
        ids = data["permalinks"].filter_map { |row| row["post_id"]&.to_i }.uniq
        data["permalink_posts"] = ids
          .each_slice(1000)
          .flat_map do |batch|
            connection.exec(
              "SELECT id,topic_id FROM posts WHERE id IN (#{batch.join(",")}) ORDER BY id",
            ).to_a
          end
        data["coverage"] = coverage(connection, result)
      else
        data["member_ids"] = connection
          .exec("SELECT id FROM users WHERE id > 0 ORDER BY id")
          .column_values(0)
          .map(&:to_i)
      end
      data
    end

    # A source-host URL must be resolved on the source. Passing it through as an
    # external destination could link to unrelated content after cutover.
    def self.resolve_source_link(connection, row, configuration)
      url = URI.parse(row.fetch("external_url"))
      origin = URI.parse(configuration.data.fetch("source_url"))
      if url.absolute? && %w[http https].include?(url.scheme) && url.host && !url.userinfo &&
           url.host.downcase != origin.host.downcase
        return
      end
      row["unresolved"] = true
      if url.userinfo || url.query || url.fragment ||
           url.host && url.host.downcase != origin.host.downcase
        return
      end
      return unless url.scheme.nil? || %w[http https].include?(url.scheme)
      return unless url.path&.start_with?("/")
      row["source_path"] = url.path.delete_prefix("/")
      type, id =
        case url.path
        when %r{\A/t/(?:[^/]+/)?(\d+)/(\d+)/?\z}
          [
            "post",
            connection
              .exec_params("SELECT id FROM posts WHERE topic_id=$1 AND post_number=$2", [$1, $2])
              .first
              &.fetch("id"),
          ]
        when %r{\A/t/(?:[^/]+/)?(\d+)/?\z}
          ["topic", $1]
        when %r{\A/p/(\d+)/?\z}
          ["post", $1]
        when %r{\A/c/(?:[^/]+/)*(\d+)/?\z}
          ["category", $1]
        when %r{\A/u/([^/]+)/?\z}i
          [
            "user",
            connection
              .exec_params("SELECT id FROM users WHERE username_lower=lower($1)", [$1])
              .first
              &.fetch("id"),
          ]
        when %r{\A/tag/([^/]+)/?\z}
          [
            "tag",
            connection
              .exec_params("SELECT id FROM tags WHERE name=$1 OR slug=$1 ORDER BY id LIMIT 1", [$1])
              .first
              &.fetch("id"),
          ]
        when %r{\A/pub/([^/]+)/?\z}
          [
            "topic",
            connection
              .exec_params("SELECT topic_id FROM published_pages WHERE slug=$1", [$1])
              .first
              &.fetch("topic_id"),
          ]
        end
      if id
        row.merge!("external_url" => nil, "#{type}_id" => id)
        row.delete("unresolved")
        row.delete("source_path")
      end
    rescue URI::InvalidURIError
      row["unresolved"] = true
    end

    def self.coverage(connection, source)
      copied =
        Merger::REQUIRED_MODELS
          .map { |model| model.safe_constantize&.table_name || model.tableize }
          .to_set
      copied.merge(
        BOTH.keys + SOURCE.keys +
          %w[
            discourse_solved_solved_topics
            discourse_solved_topic_answers
            discourse_solved_shared_issues
          ],
      )
      rebuilt = %w[user_search_data post_search_data category_search_data category_tag_stats]
      omitted =
        %w[
          site_settings
          form_templates
          schema_migrations
          schema_migration_details
          ar_internal_metadata
          user_security_keys
          user_auth_tokens
          user_auth_token_logs
          user_api_keys
          api_keys
          api_key_scopes
          email_login_codes
          user_exports
          directory_items
          application_requests
          message_bus
          stylesheet_cache
          javascript_caches
          theme_settings
          theme_fields
          themes
          color_schemes
          color_scheme_colors
          web_hooks
          web_hook_events
          backup_metadata
        ] + source.fetch("pending_entities").keys + source.fetch("omitted_plugin_entities").keys
      connection
        .exec("SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename")
        .filter_map do |row|
          name = row.fetch("tablename")
          status =
            if source.fetch("unsupported_entities")[name].to_i > 0
              "blocked"
            elsif omitted.include?(name)
              "intentionally omitted"
            elsif rebuilt.include?(name)
              "rebuilt"
            elsif copied.include?(name)
              "copied or mapped"
            else
              "unrecognized and omitted"
            end
          unless connection
                   .exec("SELECT 1 FROM #{PG::Connection.quote_ident(name)} LIMIT 1")
                   .ntuples
                   .positive?
            next
          end
          [name, status]
        end
        .to_h
    end
  end
end
