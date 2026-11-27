# frozen_string_literal: true

require_relative "template_exporter"
require_relative "workbook"
require_relative "group_mapping"
require_relative "prepared_uploads"
require_relative "audience"
require_relative "content_policy"

module BulkImport::DiscourseMerge
  class Planner
    STATES = %w[
      deleted_at
      visible
      closed
      archived
      created_at
      updated_at
      bumped_at
      last_posted_at
    ].freeze

    def initialize(configuration, inventory)
      @configuration, @inventory = configuration, inventory
    end

    def rows(name, required)
      workbook = @configuration.directory.join("mappings.xlsx")
      if workbook.exist?
        @workbook_rows ||= Workbook.new(@configuration, @inventory).read(workbook)
        return @workbook_rows.fetch(name)
      end
      path = @configuration.directory.join("mappings", name)
      unless path.file?
        raise Error, "#{path}: missing mapping file; run init or supply the required template"
      end
      table = CSV.read(path, headers: true, encoding: "bom|utf-8")
      unless table.headers && table.headers.uniq == table.headers &&
               (required - table.headers).empty?
        raise Error, "#{path}, row 1: missing or duplicate headers"
      end
      table.each_with_index.filter_map do |row, index|
        values =
          row.to_h.transform_values { |value| value.nil? ? nil : Artifacts.csv_decode(value) }
        next if values.values.all? { |value| value.to_s.strip.empty? }
        values["action"] = values["action"].to_s.strip.downcase if values.key?("action")
        values.merge("_location" => "#{path}, row #{index + 2}")
      end
    rescue CSV::MalformedCSVError => error
      raise Error, "#{path}, row #{error.line_number}: #{error.message}"
    end

    def mapping_input
      workbook = @configuration.directory.join("mappings.xlsx")
      workbook.exist? ? workbook : @configuration.directory.join("mappings")
    end

    def group_rows
      @group_rows ||=
        if @workbook_rows
          @workbook_rows["groups.csv"] || GroupMapping.defaults(@inventory)
        elsif @configuration.directory.join("mappings/groups.csv").exist?
          rows("groups.csv", %w[source_group_id action])
        else
          GroupMapping.defaults(@inventory)
        end
    end

    def group_location(id)
      row = group_rows.find { |mapping| mapping["source_group_id"].to_i == id }
      row&.fetch("_location", nil) || "Group #{id} (automatic mapping)"
    end

    def category_location(key)
      @category_locations.fetch(key)
    end

    def mapping_location(file, sheet)
      if @workbook_rows
        "#{@configuration.directory.join("mappings.xlsx")}, #{sheet}"
      else
        @configuration.directory.join("mappings", file).to_s
      end
    end

    def identifier(value, row)
      result = Integer(value)
      raise ArgumentError if result <= 0
      result
    rescue ArgumentError, TypeError
      raise Error, "#{row["_location"]}: invalid source identifier #{value.inspect}"
    end

    def normalized_path(label)
      label.to_s.strip.split(/\s*>\s*/, -1).map(&:strip).join(" > ")
    end

    def build(mappings_only: false)
      inputs = self.class.input_hashes(@configuration.directory)
      unless inputs.fetch("merge.yml") == @configuration.sha256
        raise Error, "Configuration changed while planning; run the command again"
      end
      source, destination = @inventory.values_at("source", "destination")
      source_categories = source.fetch("categories").index_by { |row| row.fetch("id").to_i }
      source_category_paths =
        source_categories.to_h do |id, row|
          [
            id.to_s,
            {
              "path" => TemplateExporter.path(id, source_categories),
              "access" => row.fetch("read_restricted") == "f" ? "public" : "restricted",
              "parent_id" => row["parent_category_id"]&.to_s,
              "description_topic_id" => row["topic_id"]&.to_i,
            },
          ]
        end
      destination_categories =
        destination.fetch("categories").index_by { |row| row.fetch("id").to_i }
      categories =
        destination
          .fetch("categories")
          .map do |row|
            {
              "key" => "destination:#{row["id"]}",
              "path" => TemplateExporter.path(row["id"].to_i, destination_categories),
              "operation" => "preserve_existing",
              "destination_category_id" => row["id"].to_i,
              "grants" => grants(destination, row["id"], "destination"),
              "access" => row["read_restricted"] == "t" ? "restricted" : "public",
            }
          end
      paths = categories.index_by { |row| row.fetch("path").join(" > ") }
      new_rows = rows("new_categories.csv", %w[path])
      category_rows = rows("categories.csv", %w[source_category_id action destination])
      mapped = {}
      @category_locations = {}
      new_rows.each do |row|
        item = register(categories, paths, row.fetch("path"), nil, row)
        @category_locations[item.fetch("key")] = row.fetch("_location")
      end
      category_rows.each do |row|
        id = identifier(row["source_category_id"], row)
        unless source_categories.key?(id) && !mapped.key?(id)
          raise Error, "#{row["_location"]}: unknown or duplicate source category"
        end
        if !MappingActions::CATEGORIES.values.include?(row["action"])
          raise Error, "#{row["_location"]}: action must be copy, reuse, topics_only, or exclude"
        end
        expected_path = source_category_paths.fetch(id.to_s).fetch("path").join(" > ")
        if row["source_path"].to_s != "" && row["source_path"] != expected_path
          raise Error,
                "#{row["_location"]}: source path does not match its ID; preserve generated source identifiers"
        end
        mapped[id] = row
        if row["action"] == "copy"
          item =
            register(categories, paths, row.fetch("destination"), source_categories.fetch(id), row)
          @category_locations[item.fetch("key")] = row.fetch("_location")
        end
      end
      unless mapped.keys.to_set == source_categories.keys.to_set
        missing = source_categories.keys - mapped.keys
        raise Error,
              "#{mapping_location("categories.csv", "Category Mapping")}: category mappings must account for every source category; add IDs #{missing.join(", ")}"
      end
      categories
        .sort_by { |item| item["path"].length }
        .each do |item|
          next if item["operation"] == "preserve_existing"
          if item["path"].length > 1
            parent = paths[item["path"][0...-1].join(" > ")]
            unless parent
              raise Error,
                    "#{category_location(item.fetch("key"))}: missing parent for #{item["path"].join(" > ")}; add the parent to the new categories mapping or change this path"
            end
            if parent["access"] == "restricted" && item["access"] == "public"
              item["grants"], item["access"] = parent["grants"], "restricted"
            end
          end
        end
      target =
        lambda do |label, location|
          paths.fetch(normalized_path(label)) do
            raise Error,
                  "#{location}: unknown destination #{label.inspect}; declare new categories explicitly"
          end
        end
      actions =
        mapped.map do |id, row|
          item =
            (
              if row["action"] == "exclude"
                nil
              else
                target.call(row["destination"], row["_location"])
              end
            )
          if row["action"] == "reuse" && item["operation"] != "preserve_existing"
            raise Error, "#{row["_location"]}: reuse requires an existing destination category"
          end
          {
            "source_category_id" => id,
            "action" => row["action"],
            "destination_key" => item && item["key"],
            "tag" => row["add_tags"].to_s.split("|").first&.strip&.downcase,
          }
        end
      overrides = {}
      seen_overrides = Set.new
      pending = []
      topics_by_id = source.fetch("topics").index_by { |row| row["id"].to_i }
      rows("topics.csv", %w[source_topic_id action destination]).each do |row|
        id = identifier(row["source_topic_id"], row)
        unless seen_overrides.add?(id)
          raise Error, "#{row["_location"]}: duplicate topic instruction"
        end
        if !MappingActions::TOPICS.values.include?(row["action"])
          raise Error, "#{row["_location"]}: action must be include, inherit, or exclude"
        end
        if row["action"] == "inherit" && row["destination"].present?
          raise Error,
                "#{row.fetch("_location")}: inherited topics cannot override their destination"
        end
        if !topics_by_id.key?(id)
          if @configuration.data.fetch("allowed_missing_topic_ids", []).exclude?(id)
            raise Error, "#{row["_location"]}: topic #{id} absent from source"
          end
          pending << row.merge(
            "_location" => row.fetch("_location").delete_prefix("#{@configuration.directory}/"),
          ).except("_tag_location")
        else
          if row["source_category_id"].to_s != "" &&
               identifier(row["source_category_id"], row) !=
                 topics_by_id.fetch(id)["category_id"].to_i
            raise Error, "#{row["_location"]}: source category changed"
          end
          overrides[id] = row
        end
      end
      definitions = source_categories.values.to_h { |row| [row["topic_id"].to_i, row["id"].to_i] }
      topics =
        source
          .fetch("topics")
          .map do |topic|
            id = topic.fetch("id").to_i
            override = overrides[id]
            if override && (definitions.key?(id) || topic["archetype"] == "private_message")
              raise Error,
                    "#{override.fetch("_location")}: topic #{id} is a PM or category description; remove this discussion exception"
            end
            row = mapped[topic["category_id"].to_i]
            exclusion_reason = nil
            if topic["shared_draft"] == "t" && source.key?("content")
              action =
                (
                  if topic["archetype"] == "regular" && !definitions.key?(id) && row &&
                       row["action"] != "exclude" && override&.fetch("action") != "exclude" &&
                       override&.fetch("destination", nil).blank?
                    "copy_shared_draft"
                  else
                    "exclude"
                  end
                )
              item = nil
            elsif topic["archetype"] == "private_message"
              action =
                (
                  if @configuration.data.fetch("include_private_messages", true)
                    "copy_private_message"
                  else
                    exclusion_reason = "private_messages_disabled"
                    "exclude"
                  end
                )
              item = nil
            else
              row = { "action" => "exclude" } if !row && override&.fetch("action") == "exclude"
              if !row && override && override["action"] == "include" &&
                   override["destination"].to_s.strip != ""
                # A deleted category can leave historical topics behind. Require
                # an explicit destination and audience review for these orphans.
                path = normalized_path(override.fetch("destination"))
                if @configuration.data.fetch("allow_access_changes", []).exclude?(path)
                  raise Error,
                        "#{override.fetch("_location")}: topic #{id} has a missing source category; review the unknown original audience with allow_access_changes for #{path}"
                end
                row = {
                  "action" => "topics_only",
                  "destination" => path,
                  "_location" => override.fetch("_location"),
                }
              end
              unless row
                raise Error,
                      "#{override&.fetch("_location") || mapping_location("topics.csv", "Topic Exceptions")}: topic #{id} has a missing source category #{topic["category_id"]}; add an explicit exclusion or a destination with audience review"
              end
              description = definitions.key?(id)
              decision = override&.fetch("action")
              excluded =
                decision == "exclude" || (decision != "include" && row["action"] == "exclude") ||
                  (description && row["action"] != "copy")
              if excluded
                exclusion_reason =
                  if description
                    "obsolete_category_description"
                  elsif decision == "exclude"
                    "topic_excluded"
                  else
                    "category_excluded"
                  end
                action = "exclude"
                item = nil
              else
                action = description ? "keep_category_description" : "copy_discussion"
                label = row["destination"]
                unless description
                  label =
                    override&.fetch("destination", nil).to_s.strip.presence ||
                      row["topic_destination"].to_s.strip.presence || label
                end
                item = target.call(label, override&.fetch("_location") || row["_location"])
              end
              if item &&
                   source_categories[topic["category_id"].to_i]&.fetch("read_restricted") == "t"
                original_grants = grants(source, topic["category_id"], "source")
                same_audience =
                  item["source_category_id"] == topic["category_id"].to_i &&
                    item["grants"] == original_grants && item["access"] != "public"
                label = item.fetch("path").join(" > ")
                approved =
                  @configuration.data.fetch("allow_access_changes", []).include?(label) ||
                    @configuration.data.fetch("category_access", {}).key?(label)
                unless same_audience || approved
                  raise Error,
                        "#{override&.fetch("_location") || row.fetch("_location")}: topic #{id} contains restricted content that changes audience at #{label}; engineer review is required"
                end
              end
            end
            tags =
              (
                if action == "copy_discussion"
                  [row, override].compact
                    .flat_map do |mapping|
                      values =
                        mapping["add_tags"]
                          .to_s
                          .split("|")
                          .map { |tag| tag.strip.downcase }
                          .reject(&:empty?)
                      if values.any?
                        location = mapping["_tag_location"] || mapping.fetch("_location")
                        unless values.all? { |tag| tag.match?(/\A[\p{L}\p{N}_-]+\z/) }
                          raise Error, "#{location}: invalid tag for topic #{id}"
                        end
                        unless @configuration.data.fetch("import_tags", true)
                          raise Error,
                                "#{location}: additional tags conflict with import_tags: false"
                        end
                      end
                      values
                    end
                    .uniq
                else
                  []
                end
              )
            instruction = {
              "source_topic_id" => id,
              "source_category_id" => topic["category_id"]&.to_i,
              "source_shared_draft" => topic["shared_draft"] == "t",
              "action" => action,
              "source_archetype" => topic.fetch("archetype"),
              "destination_key" => item && item["key"],
              "add_tags" => tags,
              "source_state" =>
                STATES.to_h do |field|
                  [
                    field,
                    (
                      if %w[visible closed archived].include?(field)
                        topic[field] == "t"
                      else
                        topic[field]
                      end
                    ),
                  ]
                end,
            }
            instruction["exclusion_reason"] = exclusion_reason if exclusion_reason
            instruction
          end
      groups =
        GroupMapping.build(
          @inventory,
          group_rows,
          location: mapping_location("groups.csv", "Group Mapping"),
        )
      staff_roles = (@workbook_rows || {}).fetch("source_staff_roles", "preserve")
      audience = Audience.new(@inventory, groups, preserve_staff_roles: staff_roles == "preserve")
      content =
        (
          if source.key?("content")
            ContentPolicy.new(
              @configuration,
              @inventory,
              categories,
              actions,
              groups,
              topics,
              audience: audience,
            ).build
          else
            {}
          end
        )
      GroupMapping.validate_exclusions!(@inventory, groups, categories, topics) do |id|
        group_location(id)
      end
      return true if mappings_only

      if @configuration.preuploaded?
        receipt_path = PreparedUploads.path_for(@configuration)
        retained = nil
        prepared_target =
          PreparedUploads.open(receipt_path) do |state|
            target =
              state.validate!(
                @inventory,
                origins: @configuration.data.values_at("source_url", "destination_url"),
                configuration: @configuration,
              )
            retained = state.retained
            target
          end
        prepared_hash = Digest::SHA256.file(receipt_path).hexdigest
      end
      if !@configuration.preuploaded? &&
           source.fetch("uploads", []).any? { |upload| [true, "t"].include?(upload["secure"]) }
        raise Error,
              "Secure source uploads require a secure-compatible transfer adapter; cross-site authentication cannot be preserved"
      end
      if @configuration.preserve_remote?
        (source.fetch("uploads", []) + source.fetch("optimized_images", [])).each do |row|
          Media.remote_url(row.fetch("url"), @configuration.data.fetch("source_url"))
        end
      end
      reuse = []
      if retained
        reuse =
          retained
            .reuse
            .fetch("uploads")
            .filter_map do |id, dest|
              { "source_upload_id" => id, "destination_upload_id" => dest } if id.positive?
            end
      elsif @configuration.preserve_remote? || @configuration.preuploaded?
        existing_uploads =
          destination
            .fetch("uploads", [])
            .reject { |row| row["sha1"].nil? }
            .index_by { |row| row["sha1"] }
        source
          .fetch("uploads", [])
          .each do |row|
            next if row.fetch("id").to_i < 0
            target_upload = existing_uploads[row["sha1"]]
            next unless target_upload
            if @configuration.preuploaded? &&
                 [row, target_upload].any? { |upload|
                   upload["secure"] == "t" || upload["access_control_post_id"]
                 }
              raise Error, "Cannot reuse upload #{row["id"]} across access-control contexts"
            end
            Media.validate_reuse!(row, target_upload)
            reuse << {
              "source_upload_id" => row.fetch("id").to_i,
              "destination_upload_id" => target_upload.fetch("id").to_i,
            }
          end
      end
      if prepared_hash && !retained &&
           content.fetch("custom_emojis", []).any? { |row| row["render"] }
        emojis = destination.fetch("content").fetch("custom_emojis").index_by { |r| r["name"] }
        PreparedUploads.open(receipt_path) do |state|
          content
            .fetch("custom_emojis")
            .each do |row|
              next unless row["render"] && (emoji = emojis[row["render"].first])
              result = state.receipt("destination", "uploads", emoji.fetch("upload_id"))
              row["render"][1] = Media.delivery_url(
                result.fetch("url"),
                result.fetch("secure"),
                prepared_target,
                @configuration.data.fetch("destination_url"),
              ) if result
            end
        end
      end
      if @configuration.preuploaded?
        included =
          topics
            .reject do |topic|
              %w[exclude exclude_obsolete_description].include?(topic.fetch("action"))
            end
            .map { |topic| topic.fetch("source_topic_id").to_i }
            .to_set
        source
          .fetch("uploads")
          .each do |row|
            next unless (control = row["access_control_post_id"])
            topic = source.fetch("controlling_posts").fetch(control, nil)
            unless topic && included.include?(topic.to_i)
              raise Error,
                    "Upload #{row["id"]} requires its controlling post #{control}; review the topic mapping"
            end
          end
      end
      unless self.class.input_hashes(@configuration.directory) == inputs
        raise Error, "Mapping inputs changed while planning; run the command again"
      end
      exceptions = source.fetch("preserved_broken_post_uploads", [])
      revisions = source.fetch("preserved_broken_revision_uploads", [])
      reviewed = exceptions + revisions
      if reviewed.any? &&
           (
             !@configuration.preuploaded? ||
               reviewed.any? { |entry| !included.include?(entry.fetch("source_topic_id")) }
           )
        raise Error, "Preserved broken uploads require included posts in preuploaded mode"
      end
      matched_ids =
        source.fetch("account_matches", []).to_set { |row| row.fetch("source_user_id").to_i }
      importable_ids = source["importable_user_ids"]&.to_set
      privileged_accounts = source.fetch("privileged_accounts", [])
      new_staff_account_ids =
        privileged_accounts.filter_map do |account|
          id = account.fetch("id").to_i
          id unless matched_ids.include?(id) || importable_ids&.exclude?(id)
        end
      {
        "format_version" => @configuration.preuploaded? ? 4 : 3,
        "content" => content,
        **(exceptions.empty? ? {} : { "preserved_broken_post_uploads" => exceptions }),
        **(revisions.empty? ? {} : { "preserved_broken_revision_uploads" => revisions }),
        "merge_member_activity" => true,
        "rewrite_letter_avatars" => true,
        "matched_avatars" => source.fetch("matched_avatars", []),
        "content_settings" => destination.dig("content", "settings"),
        "coverage" => source.dig("content", "coverage") || {},
        "source_findings" => {
          "privileged_accounts" => privileged_accounts,
          "new_staff_account_ids" => new_staff_account_ids,
          "pending_entities" => source.fetch("pending_entities", {}),
          "posts_without_topics" => source.fetch("posts_without_topics", 0),
          "unsupported_entities" => source.fetch("unsupported_entities", {}),
          "account_matches" => source.fetch("account_matches", []),
          "solved_counts" => source.fetch("solved", {}).transform_values(&:size),
          "plugin_entities" => source.fetch("plugin_entities", {}),
          "omitted_plugin_entities" => source.fetch("omitted_plugin_entities", {}),
          "canonical_account_matches" => source.fetch("canonical_account_matches", []),
        },
        "policy" => {
          "source_database" => source["database"],
          "destination_database" => destination["database"],
          "source_host" => @configuration.host("source"),
          "destination_host" => @configuration.host("destination"),
          "namespace" => @configuration.namespace,
          "source_url" => @configuration.data.fetch("source_url"),
          "destination_url" => @configuration.data.fetch("destination_url"),
          "import_tags" => @configuration.data.fetch("import_tags", true),
          "include_private_messages" => @configuration.data.fetch("include_private_messages", true),
          "source_staff_roles" => staff_roles,
        },
        "categories" => categories,
        "source_categories" => source_category_paths,
        "login_required" => {
          "source" => source.fetch("login_required", false),
          "destination" => destination.fetch("login_required", false),
        },
        "source_category_actions" => actions,
        "form_templates" => form_template_mapping(source, destination, categories),
        "groups" => groups,
        "group_access" =>
          audience.build(categories, topics.index_by { |topic| topic.fetch("source_topic_id") }),
        "topics" => topics,
        "explicit_topic_exclusions" =>
          overrides.filter_map { |id, row| id if row.fetch("action") == "exclude" }.sort,
        "pending_topics" => pending,
        "existing_destination_category_ids_to_preserve" =>
          destination["categories"].map { |row| row["id"].to_i },
        "summary" => {
          "projected_final_categories" => categories.size,
          "included_topics" => topics.count { |row| row["action"] != "exclude" },
        },
        "upload_policy" => {
          "mode" => @configuration.upload_mode,
          "media_origins" => {
            "source" => source["media_origins"],
            "destination" => destination["media_origins"],
          },
          **(
            if prepared_hash
              { "receipt_sha256" => prepared_hash, "target" => prepared_target }
            else
              {}
            end
          ),
          "destination_has_local_uploads" =>
            destination
              .values_at("uploads", "optimized_images")
              .compact
              .flatten(1)
              .any? do |upload|
                upload.fetch("id").to_i.positive? && upload.fetch("url").start_with?("/uploads/")
              end,
          **(
            if retained
              {
                "preserve_destination_uploads" => true,
                "retained_media" => retained.summary,
                "retained_ids" =>
                  retained.reuse.transform_values { |ids| ids.transform_keys(&:to_s) },
              }
            else
              {}
            end
          ),
          "reuse" => reuse,
          "source_upload_root" => @configuration.data["source_upload_root"],
          "destination_upload_root" => @configuration.data["destination_upload_root"],
          "source_hash_discrepancy_ids" =>
            @configuration.data.fetch("upload_hash_discrepancy_ids", []),
        },
        "inventory_sha256" => Digest::SHA256.hexdigest(JSON.generate(@inventory)),
        "inputs_sha256" => inputs,
        "code_sha256" =>
          (
            Pathname.new(__dir__).glob("*.rb") +
              [
                Pathname.new(__dir__).parent.join("base.rb"),
                *(
                  if @configuration.preuploaded?
                    %w[uploads_importer.rb native_upload_store.rb].map do |file|
                      Pathname.new(__dir__).parent.join(file)
                    end
                  end
                ),
                Pathname.new(__dir__).join("../../../lib/compression/safe_zip_reader.rb"),
                Pathname.new(__dir__).join("../../../Gemfile.lock"),
              ]
          ).sort.to_h do |path|
            [
              path.relative_path_from(Pathname.new(__dir__).parent).to_s,
              Digest::SHA256.file(path).hexdigest,
            ]
          end,
      }
    end

    def self.input_paths(directory)
      [
        directory.join("merge.yml"),
        *(
          if directory.join("mappings.xlsx").exist?
            [directory.join("mappings.xlsx")]
          else
            directory.join("mappings").glob("*.csv")
          end
        ),
      ].sort.index_by { |path| path.relative_path_from(directory).to_s }
    end

    def self.input_hashes(directory)
      input_paths(directory).transform_values { |path| Digest::SHA256.file(path).hexdigest }
    end

    def form_template_mapping(source, destination, categories)
      retained = categories.filter_map { |category| category["source_category_id"] }.to_set
      templates =
        destination.fetch("form_templates", []).index_by { |template| template.fetch("name") }
      source
        .fetch("category_form_templates", [])
        .each_with_object({}) do |row, mapping|
          next if retained.exclude?(row.fetch("category_id").to_i)
          target = templates[row["name"]]
          unless target && target.fetch("template") == row.fetch("template")
            raise Error,
                  "Source category #{row.fetch("category_id")} needs a matching destination form template: #{row["name"] || row.fetch("form_template_id")}"
          end
          mapping[row.fetch("form_template_id").to_s] = target.fetch("id").to_i
        end
    end

    def grants(inventory, category_id, origin)
      inventory
        .fetch("grants")
        .select { |row| row["category_id"].to_i == category_id.to_i }
        .map do |row|
          {
            "origin" => origin,
            "group_id" => row["group_id"].to_i,
            "permission_type" => row["permission_type"].to_i,
          }
        end
    end

    def register(categories, paths, label, source, row)
      label = normalized_path(label)
      path = label.split(" > ", -1)
      if path.empty? || path.any?(&:empty?) ||
           paths.keys.any? { |existing| existing.downcase == label.downcase }
        raise Error, "#{row["_location"]}: invalid or duplicate category path #{label}"
      end
      if path.length > @configuration.data.fetch("max_category_depth", 3)
        raise Error, "#{row["_location"]}: category depth exceeds destination limit"
      end
      configured = @configuration.data.fetch("category_access", {})[label]
      access_grants =
        if configured
          known_groups =
            @inventory
              .fetch("destination")
              .fetch("groups", [])
              .map { |group| group.fetch("id").to_i }
          unless configured.all? { |group_id| known_groups.include?(Integer(group_id)) }
            raise Error, "#{row["_location"]}: unknown destination group"
          end
          configured.map do |group_id|
            { "origin" => "destination", "group_id" => Integer(group_id), "permission_type" => 1 }
          end
        elsif source
          grants(@inventory.fetch("source"), source["id"], "source")
        else
          [{ "origin" => "destination", "group_id" => 0, "permission_type" => 1 }]
        end
      if access_grants.empty? && source && source["read_restricted"] == "f" && !configured
        access_grants = [{ "origin" => "destination", "group_id" => 0, "permission_type" => 1 }]
      end
      if access_grants.empty?
        raise Error, "#{row["_location"]}: category must have at least one access grant"
      end
      item = {
        "key" => "new:#{categories.size}",
        "path" => path,
        "operation" => source ? "retain_source" : "create",
        "source_category_id" => source && source["id"].to_i,
        "grants" => access_grants,
        "access" =>
          (
            if access_grants.any? { |grant| grant["group_id"] == 0 }
              "public"
            else
              "restricted"
            end
          ),
      }
      paths[label] = item
      categories << item
      item
    end

    def write(plan)
      Configuration.write(@configuration.directory.join("plan.json"), plan)
      lines = [
        "# Merge preview",
        "",
        "Included topics: #{plan["summary"]["included_topics"]}",
        "Excluded topics: #{plan.fetch("topics").count { |topic| topic.fetch("action") == "exclude" }}",
        "Mapping decisions: #{mapping_input.basename}",
        "Uploads: #{@configuration.upload_mode}",
        "",
      ]
      plan
        .fetch("preserved_broken_post_uploads", [])
        .each do |entry|
          lines << "Reviewed broken upload preserved in source post #{entry.fetch("source_post_id")}: `#{entry.fetch("url")}`"
        end
      if (revisions = plan["preserved_broken_revision_uploads"])
        lines << "Edit history preserves reviewed media references in #{revisions.size} revisions. The frozen plan lists each source revision, content hash and URL."
      end
      lines += group_access_preview(plan)
      lines += [
        "",
        "## Content and account decisions",
        "",
        *ContentPolicy.lines(ContentPolicy.summary(plan.fetch("content", {}))),
      ]
      lines += ["", "## Populated source tables", ""]
      plan
        .fetch("coverage", {})
        .group_by(&:last)
        .each do |status, entries|
          lines << "- #{status.capitalize} — #{entries.map(&:first).join(", ")}"
        end

      staff_roles = plan.fetch("policy").fetch("source_staff_roles")
      new_staff_ids = plan.dig("source_findings", "new_staff_account_ids").to_set
      preserve_staff_roles = staff_roles == "preserve"
      lines << "Source staff roles: #{MappingActions::STAFF_ROLES.key(staff_roles)}."
      lines << "New staff accounts: #{preserve_staff_roles ? new_staff_ids.size : 0}."
      if !preserve_staff_roles
        lines << "Accounts imported without source staff roles: #{new_staff_ids.size}."
        if new_staff_ids.any?
          lines << "These accounts may lose access to content that requires site-wide staff roles."
        end
      end
      lines += ["", "## Final categories", ""]
      plan["categories"]
        .sort_by { |item| item["path"] }
        .each do |item|
          lines << "- #{item["path"].join(" > ")} (#{item["operation"]}, #{item["access"]})"
        end
      lines += ["", "## Topic accounting", ""]
      plan["topics"]
        .group_by { |item| [item["action"], item["destination_key"]] }
        .each do |(action, key), values|
          label = plan["categories"].find { |item| item["key"] == key }&.fetch("path")&.join(" > ")
          action_label = {
            "copy_discussion" => "Discussions",
            "copy_shared_draft" => "Shared drafts",
            "copy_private_message" => "Private messages",
            "keep_category_description" => "Category descriptions",
            "exclude" => "Excluded topics",
          }.fetch(action)
          lines << "- #{action_label}: #{values.size}#{label ? " → " + label : ""}"
        end
      lines += ["", "## Incoming privileged accounts", ""]
      matches = @inventory.fetch("source").fetch("account_matches", [])
      canonical = @inventory.fetch("source").fetch("canonical_account_matches", [])
      lines << "Matched accounts: #{matches.size + canonical.size} (#{matches.size} by primary email; #{canonical.size} canonical system identities). Destination profiles, credentials, roles, trust levels and trust locks win."
      avatar_counts = plan.fetch("matched_avatars").pluck("choice").tally
      lines << "Matched member avatars: #{avatar_counts.fetch("destination", 0)} keep a destination upload, #{avatar_counts.fetch("source", 0)} adopt a source upload, #{avatar_counts.fetch("default", 0)} keep the destination default."
      lines << "See the private plan for account IDs."
      matched = matches.to_set { |row| row.fetch("source_user_id").to_i }
      @inventory
        .fetch("source")
        .fetch("privileged_accounts", [])
        .each do |account|
          status =
            (
              if matched.include?(account.fetch("id").to_i)
                "matched; destination flags retained"
              elsif new_staff_ids.exclude?(account.fetch("id").to_i)
                "no importable account"
              elsif !preserve_staff_roles
                "new regular account; source staff roles omitted"
              else
                "NEW privileged account: review before deployment"
              end
            )
          lines << "- #{account.fetch("username")} (source #{account.fetch("id")}): #{status}"
        end
      lines += ["", "## Custom groups", ""]
      plan
        .fetch("groups", [])
        .each do |group|
          lines << "- #{group.fetch("source_name")} → #{group.fetch("name")} (#{group.fetch("action")})"
          if group.fetch("action") == "exclude"
            lines << "  Skips this source group and its memberships; users and content remain included by their own rules. Existing destination groups are untouched."
          end
          if group["automatic_match"]
            lines << "  Automatic match: #{group.fetch("automatic_match")}"
          end
          if group.fetch("action") == "reuse"
            lines << if group["automatic_match"]
              "  Reuses the existing identical membership without adding users; destination settings and owners remain. Review shared category and PM references."
            else
              "  Adds incoming members to the destination audience; preserves destination settings and owners. Review category and PM access in both directions."
            end
          end
        end
      lines += [
        "",
        "Trust levels: destination values win matched accounts; source values are retained for new accounts. Automatic groups are not customer-mapped.",
        "",
      ]
      lines += ["", "## Additional tags", ""]
      plan["topics"]
        .flat_map { |item| item["add_tags"] }
        .tally
        .sort
        .each { |tag, count| lines << "- #{tag}: #{count} topics" }
      lines += [
        "",
        "Omitted drafts, draft sequences and moderation workflow records: #{@inventory.fetch("source").fetch("pending_entities", {})}",
        "Omitted posts without a source topic: #{plan.dig("source_findings", "posts_without_topics")}",
        "Solved records: #{plan.dig("source_findings", "solved_counts")}",
        "Omitted inactive plugin configuration/cache rows (no underlying messages, reactions or votes): #{plan.dig("source_findings", "omitted_plugin_entities")}",
        "Upload mode: #{@configuration.upload_mode}. " +
          (
            if @configuration.preuploaded?
              target = plan.dig("upload_policy", "target")
              uri = "s3://#{target["bucket"]}/#{target["prefix"]}"
              if summary = plan.dig("upload_policy", "retained_media")
                dest = summary.fetch("destination")
                staged = summary.fetch("staged")
                "Retained #{dest["uploads"]} destination originals and #{dest["optimized_images"]} thumbnails at #{target.dig("read_prefixes", "destination")} (verified from SQL). " \
                  "Reused #{summary["reused_originals"]} incoming originals, #{summary["reused_thumbnails"]} matching thumbnails and #{summary["builtin_thumbnails"]} built-in thumbnails. " \
                  "Verified #{staged["uploads"]} incoming originals and #{staged["optimized_images"]} thumbnails at #{uri}, including #{summary["additional_thumbnails"]} variants of retained originals."
              else
                "Prepared and verified at #{uri}."
              end
            elsif @configuration.preserve_remote?
              "References and metadata are verified; file bytes are not verified. Remote media depends on the original services."
            else
              "Local original file bytes are verified."
            end
          ),
        "Import incoming tags: #{@configuration.data.fetch("import_tags", true)}",
      ]
      lines += ["", "## Explicit category exclusions", ""]
      excluded_topics =
        plan
          .fetch("topics")
          .select { |topic| topic.fetch("action") == "exclude" }
          .map { |topic| topic.fetch("source_topic_id") }
          .to_set
      plan
        .fetch("source_category_actions")
        .select { |row| row.fetch("action") == "exclude" }
        .each do |row|
          id = row.fetch("source_category_id")
          ids =
            @inventory
              .dig("source", "topics")
              .select do |topic|
                topic["category_id"].to_i == id && excluded_topics.include?(topic.fetch("id").to_i)
              end
              .map { |topic| topic.fetch("id") }
          lines << "- Source category #{id}: excluded topic IDs #{ids.join(", ")}"
        end
      topic_exclusions = plan.fetch("explicit_topic_exclusions")
      if topic_exclusions.any?
        lines << "- Individually excluded topic IDs #{topic_exclusions.join(", ")}"
      end
      lines += [
        "",
        "Pending instructions: #{plan["pending_topics"].size}",
        "",
        "No database changes have been made.",
      ]
      Artifacts.write(@configuration.directory.join("preview.md"), lines.join("\n") + "\n")
    end

    def group_access_preview(plan)
      expansions = plan.dig("group_access", "expansions")
      if expansions.empty?
        return "Group reuse grants no additional access through the reviewed group memberships.", ""
      end

      paths =
        plan
          .fetch("categories")
          .to_h { |category| [category.fetch("key"), category.fetch("path").join(" > ")] }
      lines = ["## Access changes that require approval", ""]
      expansions
        .select { |change| change.fetch("type") == "category" }
        .each do |change|
          side = change.fetch("side") == "source" ? "Incoming" : "Existing"
          lines << "- #{side} restricted content in #{paths.fetch(change.fetch("key"))}: #{change.fetch("readers").size} additional readers"
        end
      expansions
        .select { |r| r["type"] == "category_moderation" }
        .each do |r|
          lines << "- #{paths.fetch(r.fetch("key"))} gains #{r.fetch("readers").size} moderators through group reuse."
        end
      expansions
        .select { |change| change.fetch("type") == "private_message" }
        .group_by { |change| change.fetch("side") }
        .each do |side, messages|
          label = side == "source" ? "incoming" : "existing"
          lines << "- #{messages.size} #{label} private messages gain readers. See group_access in the private plan for IDs."
        end
      lines << ""
    end
  end
end
