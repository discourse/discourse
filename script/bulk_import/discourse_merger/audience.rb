# frozen_string_literal: true

module BulkImport::DiscourseMerge
  # Compare direct and group grants in terms of accounts, even before copied
  # users have destination IDs. Site-wide staff access is reviewed separately.
  class Audience
    def self.expands?(plan)
      plan.dig("group_access", "expansions")&.any?
    end

    def initialize(inventory, groups, preserve_staff_roles: true)
      @preserve_staff_roles = preserve_staff_roles
      @group_rules = groups.index_by { |r| r.fetch("source_group_id") }
      @source, @destination = inventory.values_at("source", "destination")
      @matches =
        @source
          .fetch("account_matches", [])
          .to_h { |row| row.values_at("source_user_id", "destination_user_id").map(&:to_i) }
      importable = @source["importable_user_ids"]&.to_set
      @source_members =
        memberships(@source) { |id| source_account(id) if !importable || importable.include?(id) }
      @destination_members = memberships(@destination) { |id| "destination:#{id}" }
      @reused = groups.select { |group| group.fetch("action") == "reuse" }
      @source_to_destination =
        @reused.to_h { |group| group.values_at("source_group_id", "destination_group_id") }
      @projected =
        @reused
          .group_by { |group| group.fetch("destination_group_id") }
          .transform_values do |sources|
            members(@source_members, sources.map { |group| group.fetch("source_group_id") })
          end
      @projected.each { |id, incoming| incoming.merge(@destination_members.fetch(id, [])) }
    end

    def build(categories, topics)
      return { "memberships" => {}, "expansions" => [] } if @reused.empty?

      {
        "memberships" => @projected.sort.to_h { |id, readers| [id.to_s, readers.sort] },
        "expansions" =>
          private_message_expansions(topics) + category_expansions(categories, topics) +
            moderation_expansions,
      }
    end

    def moderators_preserved?(id)
      rule = @group_rules[id]
      return true if rule && rule["action"] == "copy"
      dest = destination_group(id)
      dest && projected_members([dest]).subset?(@source_members.fetch(id, Set.new))
    end

    def draft_readers_preserved?(topic, destination_id)
      settings = @source.fetch("content").fetch("source_settings")
      source_id = topic["category_id"].to_i
      return false unless settings["shared_drafts_category"].to_i == source_id
      @draft_audiences ||= {}
      @draft_audiences.fetch([source_id, destination_id]) do |key|
        @draft_audiences[key] = compare_draft_readers(source_id, destination_id, settings)
      end
    end

    def publication_readers_preserved?(topic, category, anonymous)
      return false if @source["login_required"] && anonymous
      source_id = topic["category_id"].to_i
      return true unless restricted?(@source, source_id)
      return false unless category["access"] == "restricted"
      side, id =
        if category["destination_category_id"]
          [@destination, category.fetch("destination_category_id")]
        else
          [@source, category["source_category_id"]]
        end
      readers = Set.new
      if side.dig("content", "email_access_categories")&.include?(id)
        readers.merge(projected_accounts)
      end
      readers.merge(projected_admins) if @destination.dig("content", "settings", "admin_bypass")
      category
        .fetch("grants")
        .each do |grant|
          id = grant.fetch("group_id")
          # These automatic grants can apply without a group_users row.
          return false if Group::AUTO_GROUPS.values_at(:anonymous_users, :everyone).include?(id)
          if id == Group::AUTO_GROUPS[:logged_in_users]
            readers.merge(projected_accounts)
          elsif grant["origin"] == "destination"
            readers.merge(projected_members([id]))
          elsif (dest = destination_group(id))
            readers.merge(projected_members([dest]))
          else
            readers.merge(@source_members.fetch(id, []))
          end
        end
      readers.subset?(source_category_readers(source_id))
    end

    private

    def compare_draft_readers(source_id, destination_id, settings)
      source_groups = settings.fetch("shared_drafts_allowed_groups", "1|2").split("|").map(&:to_i)
      dest_groups = @destination.dig("content", "settings", "draft_groups").map(&:to_i)
      # Core can grant these groups access without a group_users row. Treat the
      # destination's logged-in audience as every current and incoming account.
      everyone, anonymous, logged_in =
        Group::AUTO_GROUPS.values_at(:everyone, :anonymous_users, :logged_in_users)
      if dest_groups.include?(anonymous) ||
           (
             dest_groups.include?(everyone) &&
               !SiteSetting.granular_anonymous_and_logged_in_groups_permissions
           )
        return false
      end
      before = members(@source_members, source_groups)
      if source_groups.include?(logged_in) ||
           (
             source_groups.include?(everyone) &&
               settings["granular_anonymous_and_logged_in_groups_permissions"] == "f"
           )
        before.merge(source_accounts)
      end
      after = projected_members(dest_groups)
      after.merge(projected_accounts) if dest_groups.intersect?([logged_in, everyone])
      before &= source_category_readers(source_id) if restricted?(@source, source_id)
      if restricted?(@destination, destination_id)
        grants = @destination.fetch("grants").select { |r| r["category_id"].to_i == destination_id }
        groups = grants.map { |row| row["group_id"].to_i }
        # A room that admits an entire class of readers cannot narrow this estimate.
        unless groups.intersect?([everyone, anonymous, logged_in]) ||
                 @destination.dig("content", "email_access_categories")&.include?(destination_id)
          after &= projected_members(groups + [Group::AUTO_GROUPS[:staff]])
        end
      end
      before.merge(source_admins) unless settings["suppress_secured_categories_from_admin"] == "t"
      after.merge(projected_admins) if @destination.dig("content", "settings", "admin_bypass")
      after.subset?(before)
    end

    def restricted?(side, id)
      @category_restrictions ||= {}
      (
        @category_restrictions[side.fetch("database")] ||= side
          .fetch("categories")
          .to_h { |r| [r["id"].to_i, r["read_restricted"] == "t"] }
      ).fetch(id, true)
    end

    def source_category_readers(id)
      grants = @source.fetch("grants").select { |r| r["category_id"].to_i == id }
      groups = grants.map { |row| row["group_id"].to_i }
      readers = members(@source_members, groups)
      readers.merge(source_accounts) if groups.include?(Group::AUTO_GROUPS[:logged_in_users])
      unless @source.dig("content", "source_settings", "suppress_secured_categories_from_admin") ==
               "t"
        readers.merge(source_admins)
      end
      readers
    end

    def source_accounts
      @source_accounts ||= @source.fetch("importable_user_ids").to_set { |id| source_account(id) }
    end

    def projected_accounts
      @projected_accounts ||=
        source_accounts |
          @destination.fetch("content").fetch("member_ids").to_set { |id| "destination:#{id}" }
    end

    def source_admins
      @source_admins ||= @source.fetch("content").fetch("admins").to_set { |id| source_account(id) }
    end

    def projected_admins
      @projected_admins ||=
        begin
          admins = @destination.fetch("content").fetch("admins").to_set { |id| "destination:#{id}" }
          if @preserve_staff_roles
            @source
              .fetch("content")
              .fetch("admins")
              .each { |id| admins.add(source_account(id)) unless @matches.key?(id) }
          end
          admins
        end
    end

    def destination_group(id)
      return @source_to_destination.fetch(id) if @source_to_destination.key?(id)
      @automatic ||=
        begin
          names =
            @destination
              .fetch("groups")
              .select { |r| r["automatic"] == "t" }
              .to_h { |r| [r["name"], r["id"].to_i] }
          @source
            .fetch("groups")
            .select { |r| r["automatic"] == "t" }
            .to_h { |r| [r["id"].to_i, names[r["name"]]] }
        end
      @automatic[id]
    end

    def projected_members(ids)
      @incoming_automatic ||=
        begin
          sets = Hash.new { |h, k| h[k] = Set.new }
          importable = @source.fetch("importable_user_ids").to_set
          @source
            .dig("content", "authorities")
            .each do |r|
              user = r["id"].to_i
              next if importable.exclude?(user) || @matches.key?(user)
              groups = Group.desired_trust_level_groups(r["trust_level"].to_i)
              if @preserve_staff_roles
                groups << Group::AUTO_GROUPS[:admins] if r["admin"] == "t"
                groups << Group::AUTO_GROUPS[:moderators] if r["moderator"] == "t"
                groups << Group::AUTO_GROUPS[:staff] if r["admin"] == "t" || r["moderator"] == "t"
              end
              groups.each { |group| sets[group] << source_account(user) }
            end
          sets
        end
      members(@destination_members, ids) | members(@projected, ids) |
        members(@incoming_automatic, ids)
    end

    def moderation_expansions
      return [] unless @destination.dig("content", "settings", "moderation")
      @destination
        .fetch("content")
        .fetch("category_moderation_groups")
        .group_by { |r| r["category_id"].to_i }
        .filter_map do |category, rows|
          groups = rows.map { |r| r["group_id"].to_i }
          gained = members(@projected, groups) - members(@destination_members, groups)
          if gained.any?
            {
              "side" => "destination",
              "type" => "category_moderation",
              "key" => "destination:#{category}",
              "readers" => gained.sort,
            }
          end
        end
    end

    def private_message_expansions(topics)
      expansions = []
      %w[source destination].each do |side|
        inventory = side == "source" ? @source : @destination
        pm_grants =
          inventory
            .fetch("private_message_grants", [])
            .group_by { |row| row.fetch("topic_id").to_i }
        pm_grants.each do |id, grants|
          next if side == "source" && topics[id]&.fetch("action") != "copy_private_message"
          group_ids = grants.filter_map { |row| row["group_id"]&.to_i }
          user_ids = grants.filter_map { |row| row["user_id"]&.to_i }.select(&:positive?)
          if side == "source"
            reused_ids = group_ids.filter_map { |group_id| @source_to_destination[group_id] }
            original =
              members(@source_members, group_ids).merge(
                user_ids.map { |user_id| source_account(user_id) },
              )
            gained = members(@projected, reused_ids) - original
          else
            original =
              members(@destination_members, group_ids).merge(
                user_ids.map { |user_id| "destination:#{user_id}" },
              )
            gained = members(@projected, group_ids) - original
          end
          if gained.any?
            expansions << {
              "side" => side,
              "type" => "private_message",
              "id" => id,
              "readers" => gained.sort,
            }
          end
        end
      end
      expansions
    end

    def category_expansions(categories, topics)
      expansions = []
      source_categories = @source.fetch("categories").index_by { |row| row.fetch("id").to_i }
      source_topics = @source.fetch("topics").index_by { |row| row.fetch("id").to_i }
      source_grants = @source.fetch("grants").group_by { |row| row.fetch("category_id").to_i }
      routed =
        topics.each_with_object({}) do |(id, topic), result|
          next if topic.fetch("action") != "copy_discussion"
          category_id = source_topics.fetch(id)["category_id"].to_i
          next unless source_categories[category_id]&.fetch("read_restricted") == "t"
          (result[topic.fetch("destination_key")] ||= Set.new).add(category_id)
        end
      categories.each do |category|
        next unless category.fetch("access") == "restricted"
        key = category.fetch("key")
        grants = category.fetch("grants")
        existing_ids =
          grants.filter_map { |grant| grant["group_id"] if grant["origin"] == "destination" }
        source_ids = grants.filter_map { |grant| grant["group_id"] if grant["origin"] == "source" }
        reused_ids = existing_ids + source_ids.filter_map { |id| @source_to_destination[id] }
        projected = members(@projected, reused_ids)
        next if projected.empty?

        existing_audience = members(@destination_members, existing_ids)
        if category["operation"] == "preserve_existing"
          gained = projected - existing_audience
          if gained.any?
            expansions << {
              "side" => "destination",
              "type" => "category",
              "key" => key,
              "readers" => gained.sort,
            }
          end
        end

        incoming_ids = routed.fetch(key, Set.new).dup
        source_id = category["source_category_id"]
        incoming_ids.add(source_id) if source_categories[source_id]&.fetch("read_restricted") == "t"
        incoming_ids.each do |id|
          source_group_ids =
            source_grants.fetch(id, []).map { |grant| grant.fetch("group_id").to_i }
          gained = projected - members(@source_members, source_group_ids)
          if gained.any?
            expansions << {
              "side" => "source",
              "type" => "category",
              "id" => id,
              "key" => key,
              "readers" => gained.sort,
            }
          end
        end
      end

      expansions
    end

    def memberships(inventory)
      inventory
        .fetch("group_memberships", [])
        .each_with_object({}) do |row, result|
          user = row.fetch("user_id").to_i
          next unless user.positive?
          account = yield(user)
          (result[row.fetch("group_id").to_i] ||= Set.new).add(account) if account
        end
    end

    def source_account(id)
      @matches[id] ? "destination:#{@matches.fetch(id)}" : "source:#{id}"
    end

    def members(memberships, group_ids)
      group_ids.each_with_object(Set.new) { |id, result| result.merge(memberships.fetch(id, [])) }
    end
  end
end
