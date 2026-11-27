# frozen_string_literal: true

module BulkImport::DiscourseMerge
  # Decisions contain source IDs and references, never password hashes or profile answers.
  class ContentPolicy
    LABELS = {
      "user_passwords" => "Local passwords",
      "user_fields" => "Profile fields",
      "user_field_options" => "Profile field options",
      "user_custom_fields" => "Profile answers",
      "allowed_pm_users" => "Personal message allowlist entries",
      "category_moderation_groups" => "Category moderator groups",
      "shared_drafts" => "Shared drafts",
      "topic_localizations" => "Topic translations",
      "post_localizations" => "Post translations",
      "category_localizations" => "Category translations",
      "tag_localizations" => "Tag translations",
      "custom_emojis" => "Custom emoji",
      "published_pages" => "Published pages",
      "permalinks" => "Legacy aliases",
    }.freeze
    TABLES = LABELS.keys.freeze
    TARGETS = %w[topic post category tag user].freeze

    def initialize(
      configuration,
      inventory,
      categories,
      actions,
      groups,
      topics,
      audience: Audience.new(inventory, groups)
    )
      @configuration = configuration
      @source, @destination = inventory.values_at("source", "destination")
      @incoming, @existing = [@source, @destination].map { |side| side.fetch("content") }
      @settings = @existing.fetch("settings")
      @categories = categories.index_by { |r| r.fetch("key") }
      @actions = actions.index_by { |r| r.fetch("source_category_id") }
      @topics = topics.index_by { |r| r.fetch("source_topic_id") }
      @source_topics = @source.fetch("topics").index_by { |r| r.fetch("id").to_i }
      @matched =
        @source
          .fetch("account_matches")
          .to_h { |r| r.values_at("source_user_id", "destination_user_id") }
      @users =
        (
          @source.fetch("importable_user_ids") + @incoming.fetch("historical_users").map(&:to_i) +
            [-1, -2]
        ).to_set
      @groups = groups.index_by { |r| r.fetch("source_group_id") }
      @audience = audience
      @tags = @incoming.fetch("tags").index_by { |r| r.fetch("id").to_i }
      @destination_tags = @existing.fetch("tags").index_by { |r| r.fetch("name").downcase }
      @result = TABLES.index_with { [] }
    end

    def build
      passwords
      profile_fields
      permissions
      shared_drafts
      translations
      emoji
      published_pages
      permalinks
      @result
    end

    def self.summary(decisions)
      decisions.transform_values do |rows|
        rows.map { |row| row["reason"] || row.fetch("action") }.tally.sort.to_h
      end
    end

    def self.lines(summary)
      summary.filter_map do |table, counts|
        next if counts.empty?
        "- #{LABELS.fetch(table)} — " + counts.map { |reason, n| "#{n} #{reason}" }.join(", ")
      end
    end

    private

    def copy(table, row, refs: {}, values: {})
      decision = { "id" => row.fetch("id").to_i, "action" => "copied" }
      decision["refs"] = refs unless refs.empty?
      decision["values"] = values unless values.empty?
      @result.fetch(table) << decision
    end

    def reuse(table, row, existing)
      @result.fetch(table) << {
        "id" => row.fetch("id").to_i,
        "action" => "reused",
        "target" => existing.fetch("id").to_i,
      }
    end

    def skip(table, row, reason)
      @result.fetch(table) << {
        "id" => row.fetch("id").to_i,
        "action" => "skipped",
        "reason" => reason,
      }
    end

    def passwords
      @incoming
        .fetch("user_passwords")
        .each do |r|
          user = r.fetch("user_id").to_i
          algorithm = r.fetch("password_algorithm")
          reason =
            if @matched.key?(user) || !@users.include?(user) || user <= 0
              "kept destination credentials or excluded identity"
            elsif !@settings.fetch("local_passwords")
              "local password login disabled"
            elsif r["security_key"] == "t" && r["totp"] != "t"
              "require account recovery for a security key"
            elsif !supported_password?(algorithm)
              "require account recovery for an unsupported password format"
            end
          if reason
            skip("user_passwords", r, reason)
            if user.positive? && @users.include?(user) && !@matched.key?(user)
              @result.fetch("user_passwords").last["without_password"] = user
            end
          else
            copy("user_passwords", r, refs: { "user_id" => ["users", user] })
          end
        end
    end

    def supported_password?(algorithm)
      @password_formats ||= {}
      @password_formats.fetch(algorithm) do
        @password_formats[algorithm] = begin
          PasswordHasher.hash_password(
            password: "merger format check",
            salt: "merger",
            algorithm: algorithm,
          )
          true
        rescue PasswordHasher::InvalidAlgorithmError,
               PasswordHasher::UnsupportedAlgorithmError,
               ArgumentError
          false
        end
      end
    end

    def normalized(value)
      value.to_s.squish.downcase
    end

    def profile_fields
      incoming, existing =
        [@incoming, @existing].map do |s|
          s.fetch("user_fields").group_by { |r| normalized(r["name"]) }
        end
      options = @existing.fetch("user_field_options").group_by { |r| r.fetch("user_field_id").to_i }
      source_options =
        @incoming.fetch("user_field_options").group_by { |r| r.fetch("user_field_id").to_i }
      fields = {}
      incoming.each do |name, rows|
        matches = existing.fetch(name, [])
        rows.each do |r|
          id = r.fetch("id").to_i
          dest = matches.first
          visibility = %w[show_on_profile show_on_user_card searchable]
          compatible =
            dest && r["field_type_enum"] == dest["field_type_enum"] &&
              normalized(r["description"]) == normalized(dest["description"]) &&
              (visibility + ["listed"]).none? do |flag|
                dest[flag] == "t" &&
                  (r[flag] != "t" || (@source["login_required"] && !@destination["login_required"]))
              end
          if name.empty? || rows.size > 1 || matches.size > 1 || (dest && !compatible) ||
               [r, dest].compact.any? { |field|
                 field["external_type"].present? || field["external_name"].present?
               }
            skip("user_fields", r, "skipped ambiguous or incompatible field")
          elsif dest
            reuse("user_fields", r, dest)
          else
            copy(
              "user_fields",
              r,
              values:
                visibility.index_with(false).merge(
                  "show_on_signup" => false,
                  "requirement" => 0,
                  "required" => false,
                ),
            )
          end
          retained = @result.fetch("user_fields").last["action"] != "skipped"
          choices = dest ? options.fetch(dest.fetch("id").to_i, []) : source_options.fetch(id, [])
          by_value = choices.index_by { |v| v.fetch("value") }
          fields[id] = [r.fetch("field_type_enum").to_i, by_value] if retained
          source_options
            .fetch(id, [])
            .each do |option|
              if !retained || (dest && !by_value.key?(option["value"]))
                skip("user_field_options", option, "omitted by field policy")
              elsif dest
                reuse("user_field_options", option, by_value.fetch(option["value"]))
              else
                copy("user_field_options", option, refs: { "user_field_id" => ["user_fields", id] })
              end
            end
        end
      end
      known_options = @result.fetch("user_field_options").pluck("id").to_set
      @incoming
        .fetch("user_field_options")
        .each do |r|
          if known_options.exclude?(r.fetch("id").to_i)
            skip("user_field_options", r, "missing field")
          end
        end
      @incoming
        .fetch("user_custom_fields")
        .each do |r|
          user = r.fetch("user_id").to_i
          id = r.fetch("name").delete_prefix("user_field_").to_i
          field = fields[id]
          if !field || user <= 0 || !@users.include?(user) || @matched.key?(user)
            skip("user_custom_fields", r, "omitted by account or field policy")
          elsif [2, 3].include?(field.first) && !field.last.key?(r["choice"])
            skip("user_custom_fields", r, "with incompatible choices")
          else
            copy(
              "user_custom_fields",
              r,
              refs: {
                "name" => ["user_fields", id],
                "user_id" => ["users", user],
              },
            )
          end
        end
    end

    def permissions
      @incoming
        .fetch("allowed_pm_users")
        .each do |r|
          owner, sender = r.values_at("user_id", "allowed_pm_user_id").map(&:to_i)
          if owner > 0 && @users.include?(owner) && @users.include?(sender) && !@matched.key?(owner)
            identity = [owner, @matched[sender] || "source:#{sender}"]
            unless (@pm_pairs ||= Set.new).add?(identity)
              next skip("allowed_pm_users", r, "duplicate mapped sender")
            end
            copy(
              "allowed_pm_users",
              r,
              refs: {
                "user_id" => ["users", owner],
                "allowed_pm_user_id" => ["users", sender],
              },
            )
          else
            skip("allowed_pm_users", r, "kept destination preferences or unmapped sender")
          end
        end
      @incoming
        .fetch("category_moderation_groups")
        .each do |r|
          id, group = r.values_at("category_id", "group_id").map(&:to_i)
          if @settings.fetch("moderation") && @actions.dig(id, "action") == "copy" &&
               @audience.moderators_preserved?(group)
            dest = @groups.dig(group, "destination_group_id")
            unless (@moderation_pairs ||= Set.new).add?([id, dest || "source:#{group}"])
              next skip("category_moderation_groups", r, "duplicate mapped moderator group")
            end
            copy(
              "category_moderation_groups",
              r,
              refs: {
                "category_id" => ["categories", id],
                "group_id" => ["groups", group],
              },
            )
          else
            skip("category_moderation_groups", r, "kept destination moderation policy")
          end
        end
    end

    def shared_drafts
      target = @settings.fetch("draft_category")
      @incoming
        .fetch("shared_drafts")
        .each do |r|
          topic = @topics[r.fetch("topic_id").to_i]
          intended = @actions.dig(r.fetch("category_id").to_i, "destination_key")
          if topic && topic["action"] == "copy_shared_draft" && target.positive? && intended &&
               intended != "destination:#{target}" && @categories.key?("destination:#{target}") &&
               @audience.draft_readers_preserved?(
                 @source_topics.fetch(r.fetch("topic_id").to_i),
                 target,
               )
            topic["destination_key"] = "destination:#{target}"
            copy(
              "shared_drafts",
              r,
              refs: {
                "topic_id" => ["topics", r.fetch("topic_id").to_i],
                "category_id" => ["category_keys", intended],
              },
            )
          else
            topic&.merge!(
              "action" => "exclude",
              "destination_key" => nil,
              "exclusion_reason" => "shared_draft_omitted",
              "add_tags" => [],
            )
            skip("shared_drafts", r, "omitted with dependent posts to preserve draft access")
          end
        end
    end

    def included_topic?(id)
      topic = @topics[id.to_i]
      topic && topic["action"] != "exclude"
    end

    def translations
      %w[topic post category tag].each do |kind|
        table = "#{kind}_localizations"
        column = "#{kind}_id"
        existing =
          @existing.fetch(table, []).index_by { |r| [r.fetch(column).to_i, r.fetch("locale")] }
        proposed = Set.new
        @incoming
          .fetch(table)
          .each do |r|
            id = r.fetch(column).to_i
            dest_id = existing_target(kind, id)
            if %w[topic post].include?(kind) &&
                 (
                   !included_topic?(r["topic_id"]) ||
                     !@users.include?(r.fetch("localizer_user_id").to_i)
                 ) || kind == "category" && !%w[copy reuse].include?(@actions.dig(id, "action")) ||
                 kind == "tag" && !import_tag?(id)
              skip(table, r, "missing retained parent or translator")
            elsif dest_id && (match = existing[[dest_id, r.fetch("locale")]])
              reuse(table, r, match)
            else
              if dest_id && !proposed.add?([dest_id, r.fetch("locale")])
                skip(table, r, "another retained translation uses this locale")
                next
              end
              refs = { column => [kind.pluralize, id] }
              refs["localizer_user_id"] = ["users", r.fetch("localizer_user_id").to_i] if r[
                "localizer_user_id"
              ]
              copy(table, r, refs: refs)
            end
          end
      end
    end

    def import_tag?(id)
      @configuration.data.fetch("import_tags", true) && @tags.key?(id)
    end

    def existing_target(kind, id)
      case kind
      when "category"
        @categories.dig(@actions.dig(id, "destination_key"), "destination_category_id")
      when "user"
        id.in?([-1, -2]) ? id : @matched[id]
      when "tag"
        @destination_tags.dig(@tags.dig(id, "name")&.downcase, "id")&.to_i
      end
    end

    def emoji
      existing = @existing.fetch("custom_emojis").index_by { |r| r.fetch("name") }
      @incoming
        .fetch("custom_emojis")
        .each do |r|
          dest = existing[r.fetch("name")]
          if dest && dest["sha1"].present? && dest["sha1"] == r["sha1"]
            reuse("custom_emojis", r, dest)
          elsif dest || Emoji.exists?(r["name"])
            skip("custom_emojis", r, "kept destination emoji")
            url = dest ? dest.fetch("url") : Emoji[r.fetch("name")].cdn_url
            @result.fetch("custom_emojis").last["render"] = [
              r.fetch("name"),
              Media.remote_url(url, @configuration.data.fetch("destination_url")),
            ]
          elsif !@users.include?(r["user_id"].to_i) || r["sha1"].blank?
            skip("custom_emojis", r, "missing upload or owner")
          else
            copy(
              "custom_emojis",
              r,
              refs: {
                "upload_id" => ["uploads", r["upload_id"].to_i],
                "user_id" => ["users", r["user_id"].to_i],
              },
            )
          end
        end
    end

    def published_pages
      taken = @existing.fetch("published_pages").pluck("slug").to_set
      source_settings = @incoming.fetch("source_settings")
      source_public =
        source_settings["enable_page_publishing"] == "t" &&
          source_settings["secure_uploads"] != "t" &&
          (
            !@source["login_required"] ||
              source_settings["show_published_pages_login_required"] == "t"
          )
      @incoming
        .fetch("published_pages")
        .each do |r|
          topic = @topics[r.fetch("topic_id").to_i]
          category = topic && @categories[topic["destination_key"]]
          page = PublishedPage.new(slug: r.fetch("slug"))
          page.slug_format
          if !@settings.fetch("publishing") || source_settings["enable_page_publishing"] != "t" ||
               page.errors[:slug].present? || source_settings["secure_uploads"] == "t" || !topic ||
               topic["action"] != "copy_discussion" || taken.include?(r["slug"]) ||
               topic.dig("source_state", "deleted_at") ||
               topic.dig("source_state", "visible") != true
            skip("published_pages", r, "omitted by publication policy or slug conflict")
          elsif r["public"] == "f" &&
                !@audience.publication_readers_preserved?(
                  @source_topics.fetch(r["topic_id"].to_i),
                  category,
                  @settings.fetch("anonymous_publishing"),
                )
            skip("published_pages", r, "omitted to preserve publication visibility")
          elsif r["public"] == "t" && !source_public && @settings.fetch("anonymous_publishing")
            skip("published_pages", r, "omitted to preserve publication visibility")
          else
            copy(
              "published_pages",
              r,
              refs: {
                "topic_id" => ["topics", r.fetch("topic_id").to_i],
              },
              values: {
                "public" => r["public"] == "t" && category["access"] == "public",
              },
            )
          end
          decision = @result.fetch("published_pages").last
          decision["retained_topic"] = r.fetch("topic_id").to_i if decision["action"] ==
            "skipped" && included_topic?(r.fetch("topic_id"))
        end
    end

    def permalinks
      existing = @existing.fetch("permalinks").index_by { |r| r.fetch("url") }
      post_topics =
        @incoming.fetch("permalink_posts").to_h { |r| r.values_at("id", "topic_id").map(&:to_i) }
      groups =
        @incoming
          .fetch("permalinks")
          .group_by { |r| UrlHelper.encode(Permalink.normalize_url(r.fetch("url"))) }
      groups.each do |path, rows|
        row = rows.first
        targets = rows.map { |entry| permalink_target(entry, post_topics) }.uniq
        if reserved_path?(path) || targets.size != 1 || targets.first.nil?
          rows.each do |entry|
            skip("permalinks", entry, "skipped reserved, ambiguous or unresolved alias")
          end
          next
        end
        kind, target = targets.first
        if (destination = existing[path])
          same =
            (
              if kind == "external"
                destination["external_url"] == target
              else
                destination["#{kind}_id"]&.to_i == target
              end
            )
          rows.each do |entry|
            if same
              reuse("permalinks", entry, destination)
            else
              skip("permalinks", entry, "kept destination alias")
            end
          end
        else
          values =
            TARGETS
              .to_h { |key| ["#{key}_id", nil] }
              .merge("url" => path, "external_url" => row["external_url"])
          refs =
            (
              if kind == "external"
                {}
              else
                { "#{kind}_id" => [kind.pluralize, row.fetch("#{kind}_id").to_i] }
              end
            )
          copy("permalinks", row, refs: refs, values: values)
          rows
            .drop(1)
            .each do |entry|
              @result.fetch("permalinks") << {
                "id" => entry.fetch("id").to_i,
                "action" => "reused",
                "source_target" => row.fetch("id").to_i,
              }
            end
        end
      end
    end

    def permalink_target(row, post_topics)
      kind = TARGETS.find { |key| row["#{key}_id"] }
      unless kind
        return "external", row["external_url"] if row["external_url"].present? && !row["unresolved"]
        return
      end
      id = row.fetch("#{kind}_id").to_i
      retained =
        case kind
        when "topic"
          included_topic?(id)
        when "post"
          included_topic?(post_topics[id])
        when "category"
          @actions.dig(id, "destination_key")
        when "user"
          @users.include?(id)
        when "tag"
          import_tag?(id)
        end
      return unless retained
      [kind, existing_target(kind, id) || (kind == "category" ? retained : "source:#{id}")]
    end

    def reserved_path?(path)
      if path.blank? || path.split("/").intersect?(%w[. ..]) || path.start_with?("/", "\\") ||
           path.match?(
             %r{\A(?:t|p|c|tag|tags|u|g|pub|admin|uploads|assets|images|stylesheets|session|#{Regexp.escape(@configuration.namespace)})(?:/|\?|$)}i,
           )
        return true
      end
      route = UrlHelper.rails_route_from_url("/#{path}")
      route && route[:controller] != "permalinks"
    rescue ActionController::RoutingError
      false
    rescue URI::Error, ArgumentError
      true
    end
  end
end
