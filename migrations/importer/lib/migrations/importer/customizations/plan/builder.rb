# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      class Plan
        # Turns a database diff report (see `customizations diff --json`) into
        # a plan. Facts about the site the changes live on (setting types, theme
        # names, whether a group was imported, ...) come from `facts`, so the
        # builder itself stays free of Rails.
        class Builder
          THEME_ID_TABLES = %w[
            theme_fields
            theme_settings
            theme_site_settings
            theme_translation_overrides
            theme_modifier_sets
            theme_settings_migrations
          ].freeze

          HANDLED_TABLES =
            (
              %w[
                site_settings
                themes
                child_themes
                remote_themes
                category_groups
                color_schemes
                color_scheme_colors
                groups
                categories
                translation_overrides
              ] + THEME_ID_TABLES
            ).freeze

          def initialize(diff, facts)
            @tables = diff.fetch("tables", {})
            @facts = facts
            @trailer = []
          end

          # @return [Array(Hash, Array<String>)] the plan and comment lines for its end
          def build
            plan = {
              "format_version" => FORMAT_VERSION,
              "site_settings" => site_settings,
              "themes" => themes,
              "color_schemes" => color_schemes,
              "groups" => groups,
              "categories" => categories,
              "translation_overrides" => translation_overrides,
            }
            [plan, trailer_lines]
          end

          private

          def site_settings
            after = added_and_changed("site_settings").index_by { |row| row["name"] }
            before = removed_and_before("site_settings").index_by { |row| row["name"] }

            items =
              after.filter_map do |name, row|
                next if before.key?(name) && before[name]["value"] == row["value"]
                { "name" => name }.merge(Rules.site_setting(name, row["value"], @facts))
              end

            (before.keys - after.keys).each do |name|
              items << { "name" => name, "reset" => true }.merge(
                Rules.site_setting(name, nil, @facts),
              )
            end

            items.sort_by { |item| item["name"] }
          end

          def themes
            changed_theme_ids.sort.filter_map do |id|
              info = @facts.theme(id)
              if info.nil?
                @trailer << "themes: theme #{id} changed but no longer exists, not transferred"
                next
              end

              item = { "name" => info[:name] }
              item["system_id"] = id if info[:system]
              item["target"] = "template"
              item["note"] = "installed from git" if info[:git]
              item
            end
          end

          def changed_theme_ids
            ids = Set.new

            meaningful_rows("themes").each { |row| ids << row["id"].to_i }

            THEME_ID_TABLES.each do |table|
              meaningful_rows(table).each do |row|
                next if table == "theme_fields" && screenshot_noise?(row)
                ids << row["theme_id"].to_i if row["theme_id"]
              end
            end

            meaningful_rows("child_themes").each do |row|
              ids << row["parent_theme_id"].to_i
              ids << row["child_theme_id"].to_i
            end

            meaningful_rows("color_schemes").each do |row|
              ids << row["theme_id"].to_i if row["theme_id"].present?
            end

            note_removed("themes")
            ids
          end

          # System themes get their screenshots re-uploaded on every reseed.
          def screenshot_noise?(row)
            return false if row["theme_id"].to_i >= 0

            row["type_id"] == Rules::THEME_SCREENSHOT_FIELD_TYPE ||
              row["name"].to_s.start_with?("screenshot") || row["_changed_columns"] == ["upload_id"]
          end

          def color_schemes
            ids = Set.new
            meaningful_rows("color_schemes").each { |row| ids << row["id"].to_i }
            meaningful_rows("color_scheme_colors").each { |row| ids << row["color_scheme_id"].to_i }
            note_removed("color_schemes")

            ids.sort.filter_map do |id|
              info = @facts.color_scheme(id)
              next if info.nil?

              item = { "name" => info[:name] }
              owner = info[:theme_id] && @facts.theme(info[:theme_id])
              if owner && !owner[:system]
                item.merge!("target" => "skip", "note" => "comes with theme '#{owner[:name]}'")
              else
                item["theme"] = { "name" => owner[:name], "system_id" => info[:theme_id] } if owner
                item["target"] = "template"
              end
              item
            end
          end

          def groups
            # Ids can differ between the two databases; names are unique.
            attribute_changes(
              "groups",
              Rules::GROUP_ATTRIBUTES,
              pair_by: "name",
            ).filter_map do |id, attributes|
              info = @facts.group(id)
              next if info.nil?

              item = { "name" => info[:name] }
              item["match"] = info[:match] if info[:imported]
              item["attributes"] = attributes
              item.merge(Rules.group(info))
            end
          end

          def categories
            changes = attribute_changes("categories", Rules::CATEGORY_ATTRIBUTES).to_h
            changed_permission_category_ids.each do |id|
              changes[id] = (changes[id] || []) + [Rules::CATEGORY_PERMISSIONS]
            end

            changes.sort.filter_map do |id, attributes|
              info = @facts.category(id)
              next if info.nil?

              { "name" => info[:name], "match" => info[:match], "attributes" => attributes }.merge(
                Rules.category(info),
              )
            end
          end

          def translation_overrides
            key = ->(row) { [row["locale"], row["translation_key"]] }
            after = added_and_changed("translation_overrides").index_by(&key)
            before = removed_and_before("translation_overrides").index_by(&key)

            items =
              after.filter_map do |(locale, translation_key), row|
                next if before[[locale, translation_key]]&.dig("value") == row["value"]
                { "locale" => locale, "key" => translation_key }.merge(
                  Rules.translation_override(translation_key),
                )
              end

            (before.keys - after.keys).each do |locale, translation_key|
              items << { "locale" => locale, "key" => translation_key, "reset" => true }.merge(
                Rules.translation_override(translation_key),
              )
            end

            items.sort_by { |item| [item["locale"], item["key"]] }
          end

          # @return [Array<Array(Integer, Array<String>)>] id and plan attribute names
          # Pairs before and after rows by `pair_by`. A row whose key exists on
          # both sides has its counterpart in the diff too, unless both are equal.
          def attribute_changes(table, allowed, pair_by: "id")
            before = removed_and_before(table).index_by { |row| row[pair_by] }
            data = table_data(table)
            after =
              data.fetch("added", []) +
                data
                  .fetch("changed", [])
                  .map { |change| change["after"].merge(change["diffs"].transform_values(&:last)) }

            removed = before.keys - after.map { |row| row[pair_by] }
            if removed.any?
              @trailer << "#{table}: #{removed.size} removed row(s), deletions are not transferred"
            end

            after
              .filter_map do |row|
                old = before[row[pair_by]]
                columns =
                  allowed.select do |column|
                    next false unless row.key?(column)
                    if old
                      old[column] != row[column] && !Rules.blank_equal?(old[column], row[column])
                    else
                      !@facts.default_value?(table, column, row[column])
                    end
                  end
                [row["id"].to_i, columns] if columns.any?
              end
              .sort
              .map { |id, columns| [id, columns.map { |c| Rules.plan_attribute_name(c) }] }
          end

          # Compares (group, permission) sets so re-saving the same permissions,
          # which recreates the rows, isn't reported. Rows equal in both
          # databases are absent from the diff on both sides, so they cancel out.
          def changed_permission_category_ids
            permissions = ->(rows) do
              rows
                .group_by { |row| row["category_id"].to_i }
                .transform_values do |group_rows|
                  group_rows.map { |r| [r["group_id"], r["permission_type"]] }.to_set
                end
            end

            before = permissions.call(removed_and_before("category_groups"))
            after = permissions.call(added_and_changed("category_groups"))
            (before.keys | after.keys).select do |id|
              (before[id] || Set.new) != (after[id] || Set.new)
            end
          end

          def table_data(table)
            @tables[table] || {}
          end

          def added_and_changed(table)
            data = table_data(table)
            data.fetch("added", []) + data.fetch("changed", []).map { |change| change["after"] }
          end

          # Rows as they were in the "before" database.
          def removed_and_before(table)
            data = table_data(table)
            before =
              data
                .fetch("changed", [])
                .map { |change| change["after"].merge(change["diffs"].transform_values(&:first)) }
            data.fetch("removed", []) + before
          end

          # Added rows plus changed rows with more than noise columns changed.
          # Changed rows carry their changed column names in `_changed_columns`.
          def meaningful_rows(table)
            data = table_data(table)
            changed =
              data
                .fetch("changed", [])
                .filter_map do |change|
                  columns = change["diffs"].keys - Rules::NOISE_COLUMNS
                  change["after"].merge("_changed_columns" => columns) if columns.any?
                end
            data.fetch("added", []) + changed
          end

          def note_removed(table)
            removed = table_data(table).fetch("removed", []).size
            return if removed == 0

            @trailer << "#{table}: #{removed} removed row(s), deletions are not transferred"
          end

          def trailer_lines
            unhandled =
              @tables.filter_map do |table, data|
                next if HANDLED_TABLES.include?(table)

                counts = %w[added removed changed].map { |kind| Array(data[kind]).size }
                next if counts.sum == 0

                "  #{table}: #{counts[0]} added, #{counts[1]} removed, #{counts[2]} changed"
              end

            lines = []
            if @trailer.any?
              lines << "Notes:"
              lines.concat(@trailer.uniq.map { |line| "  #{line}" })
            end
            if unhandled.any?
              lines << "" if lines.any?
              lines << "Not handled, review manually:"
              lines.concat(unhandled.sort)
            end
            lines
          end
        end
      end
    end
  end
end
