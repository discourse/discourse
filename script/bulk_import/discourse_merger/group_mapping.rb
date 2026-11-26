# frozen_string_literal: true

require_relative "configuration"
require_relative "mapping_actions"
require "active_support/core_ext/object/blank"

module BulkImport::DiscourseMerge
  class GroupMapping
    def self.custom(groups)
      groups.select { |group| group["name"].present? && ![true, "t"].include?(group["automatic"]) }
    end

    def self.grants(grants, groups)
      grants
        .map do |grant|
          id =
            (
              if grant.fetch("origin") == "source"
                groups.fetch(grant.fetch("group_id"))
              else
                grant.fetch("group_id")
              end
            )
          { group_id: id, permission_type: grant.fetch("permission_type") }
        end
        .group_by { |grant| grant.fetch(:group_id) }
        .map do |id, rows|
          { group_id: id, permission_type: rows.map { |row| row.fetch(:permission_type) }.min }
        end
    end

    def self.excluded(instructions)
      instructions
        .select { |group| group.fetch("action") == "exclude" }
        .map { |group| group.fetch("source_group_id") }
        .to_set
    end

    def self.validate_exclusions!(inventory, groups, categories, topics, &location)
      excluded = self.excluded(groups)
      return if excluded.empty?
      source = inventory.fetch("source")
      unless source.key?("group_dependencies")
        raise Error, "Group exclusions require a fresh inventory with group dependency evidence"
      end
      retained = categories.filter_map { |category| category["source_category_id"] }.to_set
      matched_users =
        source
          .fetch("account_matches", [])
          .map { |match| match.fetch("source_user_id").to_i }
          .to_set
      included =
        topics
          .reject { |topic| topic.fetch("action") == "exclude" }
          .map { |topic| topic.fetch("source_topic_id") }
          .to_set
      categories.each do |category|
        next if category.fetch("operation") == "preserve_existing"
        category
          .fetch("grants")
          .each do |grant|
            id = grant.fetch("group_id")
            if grant.fetch("origin") == "source" && excluded.include?(id)
              raise Error,
                    "#{location.call(id)}: Excluded group #{id} is required by category #{category.fetch("path").join(" > ")}; map the group or explicitly replace category access"
            end
          end
      end
      source
        .fetch("group_dependencies")
        .each do |reference|
          id = reference.fetch("group_id").to_i
          next if excluded.exclude?(id)
          if reference.fetch("table_name") == "user_custom_fields" && reference["user_id"]
            user_id = reference.fetch("user_id").to_i
            next if user_id <= 0 || matched_users.include?(user_id)
          end
          next if reference["topic_id"] && !included.include?(reference.fetch("topic_id").to_i)
          if reference["category_id"] && !retained.include?(reference.fetch("category_id").to_i)
            next
          end
          raise Error,
                "#{location.call(id)}: Excluded group #{id} is required by #{reference.fetch("table_name")} (topic #{reference["topic_id"]}, category #{reference["category_id"]}, tag group #{reference["tag_group_id"]}); resolve the dependency before excluding it"
        end
    end

    def self.metadata_group_ids(value)
      case value
      when Array
        value.each_with_object(Set.new) { |item, ids| ids.merge(metadata_group_ids(item)) }
      when Hash
        value.each_with_object(Set.new) do |(key, item), ids|
          if %w[group_id group_ids].include?(key.to_s)
            Array(item).each { |id| ids << id.to_i if id.to_s.match?(/\A-?\d+\z/) }
          end
          ids.merge(metadata_group_ids(item))
        end
      else
        Set.new
      end
    end

    def self.metadata_references?(value, excluded)
      (metadata_group_ids(value) & excluded).any?
    end

    def self.preserve_metadata(value, excluded, namespace)
      case value
      when Array
        value.map { |item| preserve_metadata(item, excluded, namespace) }
      when Hash
        value.to_h do |key, item|
          changed =
            %w[group_id group_ids].include?(key.to_s) &&
              metadata_references?({ key => item }, excluded)
          [
            changed ? "#{namespace}_original_#{key}" : key,
            changed ? item : preserve_metadata(item, excluded, namespace),
          ]
        end
      else
        value
      end
    end

    def self.defaults(inventory)
      custom(inventory.fetch("source").fetch("groups", [])).map do |group|
        {
          "source_group_id" => group.fetch("id"),
          "action" => "auto",
          "name" => "",
          "destination_group_id" => "",
        }
      end
    end

    def self.matching_evidence(inventory)
      incoming, destination = inventory.values_at("source", "destination")
      unless incoming.key?("group_memberships") && incoming.key?("group_user_matches") &&
               destination.key?("group_memberships")
        return
      end
      {
        source_members:
          incoming.fetch("group_memberships").group_by { |row| row.fetch("group_id").to_i },
        destination_members:
          destination.fetch("group_memberships").group_by { |row| row.fetch("group_id").to_i },
        matches:
          incoming
            .fetch("group_user_matches")
            .to_h do |row|
              [row.fetch("source_user_id").to_i, row.fetch("destination_user_id").to_i]
            end,
        covered: destination["group_membership_group_ids"]&.map(&:to_i)&.to_set,
      }
    end

    def self.identical_target(inventory, group, evidence)
      destination = inventory.fetch("destination")
      candidates =
        custom(destination.fetch("groups", [])).select do |target|
          target.fetch("name").downcase == group.fetch("name").downcase
        end
      unless candidates.size == 1
        return nil, "No unique custom destination group with the same name"
      end
      target = candidates.first
      unless evidence
        return nil, "Membership evidence unavailable; export a fresh inventory to compare"
      end
      covered = evidence.fetch(:covered)
      if covered && !covered.include?(target.fetch("id").to_i)
        return nil, "Destination membership evidence unavailable"
      end
      matches = evidence.fetch(:matches)
      members = evidence.fetch(:source_members).fetch(group.fetch("id").to_i, [])
      if members.any? { |row|
           row.fetch("user_id").to_i <= 0 || !matches.key?(row.fetch("user_id").to_i)
         }
        return nil, "Some incoming members are new or cannot be matched to destination accounts"
      end
      incoming_ids = members.map { |row| matches.fetch(row.fetch("user_id").to_i) }.to_set
      destination_ids =
        evidence
          .fetch(:destination_members)
          .fetch(target.fetch("id").to_i, [])
          .map { |row| row.fetch("user_id").to_i }
          .to_set
      unless incoming_ids == destination_ids
        return nil, "Member lists differ after account matching"
      end
      [
        target.fetch("id").to_i,
        "Same name and exact member list after account matching; destination settings and owners retained",
      ]
    end

    def self.build(inventory, rows, location: "Group mapping")
      source =
        custom(inventory.fetch("source").fetch("groups", [])).index_by do |group|
          group.fetch("id").to_i
        end
      destination =
        custom(inventory.fetch("destination").fetch("groups", [])).index_by do |group|
          group.fetch("id").to_i
        end
      taken =
        inventory
          .fetch("destination")
          .fetch("groups", [])
          .filter_map { |group| group["name"]&.downcase }
          .to_set
      reserved =
        taken | source.values.map { |group| group.fetch("name").downcase }.to_set |
          rows.filter_map { |row| row["name"].presence&.downcase }.to_set
      seen = Set.new
      maximum = inventory.fetch("destination").fetch("group_name_max_length", 20).to_i
      evidence = matching_evidence(inventory)
      rows
        .map { |row| [group_identifier(row, "source_group_id", location), row] }
        .sort_by(&:first)
        .map do |id, row|
          unless source.key?(id) && seen.add?(id)
            raise Error, "Unknown, automatic or duplicate source group #{id}"
          end
          action = row.fetch("action")
          automatic_reason = nil
          if action == "auto"
            if row["name"].present? || row["destination_group_id"].present?
              raise Error, "Group #{id}: automatic matching cannot specify a rename or destination"
            end
            target, automatic_reason = identical_target(inventory, source.fetch(id), evidence)
            action = target ? "reuse" : "copy"
            row = row.merge("destination_group_id" => target || "")
          end
          if MappingActions::GROUPS.values.exclude?(action)
            raise Error, "Group #{id}: action must be auto, copy, reuse or exclude"
          end
          item = {
            "source_group_id" => id,
            "source_name" => source.fetch(id).fetch("name"),
            "action" => action,
          }
          item["automatic_match"] = automatic_reason if automatic_reason
          if action == "exclude"
            if row["name"].present? || row["destination_group_id"].present?
              raise Error, "Group #{id}: exclusion cannot specify a rename or destination"
            end
            item.merge("name" => item.fetch("source_name"), "destination_group_id" => nil)
          elsif action == "reuse"
            target = group_identifier(row, "destination_group_id", location)
            unless destination.key?(target)
              raise Error, "Group #{id}: choose an existing custom destination group"
            end
            raise Error, "Group #{id}: rename cannot be used with reuse" if row["name"].present?
            item.merge(
              "destination_group_id" => target,
              "name" => destination.fetch(target).fetch("name"),
            )
          else
            if row["destination_group_id"].present?
              raise Error, "Group #{id}: copy cannot select an existing destination"
            end
            name = row["name"].presence || item.fetch("source_name")
            unless name.match?(/\A[\p{L}\p{N}_.-]+\z/) && name.length <= maximum
              raise Error, "Group #{id}: invalid or excessively long group name"
            end
            if taken.include?(name.downcase)
              suffix = 0
              begin
                suffix += 1
                tail = "_#{suffix}"
                candidate = name[0, maximum - tail.length] + tail
              end while reserved.include?(candidate.downcase)
              name = candidate
            end
            taken << name.downcase
            reserved << name.downcase
            item.merge("name" => name, "destination_group_id" => nil)
          end
        rescue Error => error
          raise Error, row["_location"] ? "#{row["_location"]}: #{error.message}" : error.message
        end
        .tap do
          unless seen == source.keys.to_set
            missing = source.keys - seen.to_a
            raise Error,
                  "#{location}: Group mappings must account for every custom source group; add IDs #{missing.join(", ")}"
          end
        end
    end

    def self.group_identifier(row, field, location)
      Integer(row[field])
    rescue ArgumentError, TypeError
      prefix = field == "source_group_id" ? "#{row["_location"] || location}: " : ""
      raise Error, "#{prefix}Group mapping contains an invalid group identifier in #{field}"
    end
  end

  class AssociationFilter
    def initialize(indexes, existing: [], permission: false)
      @indexes = indexes
      @seen = indexes.map { Set.new }
      @existing = existing.to_set { |key| key.map(&:to_s) }
      @permissions = {} if permission
    end

    def accept?(row)
      keys =
        @indexes.map do |columns|
          values = row.values_at(*columns)
          values.map(&:to_s) if values.none?(&:nil?)
        end
      return false if @existing.include?(keys.first)
      if @permissions
        value = row.fetch("permission_type")
        previous = @permissions[keys.first] ||= value
        unless previous == value
          raise Error, "Conflicting permissions for mapped tag group and group #{keys.first}"
        end
      end
      return false if keys.each_with_index.any? { |key, index| key && @seen[index].include?(key) }
      keys.each_with_index { |key, index| @seen[index] << key if key }
      true
    end
  end

  class GroupMemberships
    def initialize(existing, reused_group_ids)
      @seen = existing.to_set
      @reused = reused_group_ids.to_set
    end

    def add(row)
      return if row.fetch("user_id").to_i <= 0
      key = [row.fetch("group_id").to_i, row.fetch("user_id").to_i]
      return unless @seen.add?(key)
      row["owner"] = "f" if @reused.include?(key.first)
      row
    end
  end
end
