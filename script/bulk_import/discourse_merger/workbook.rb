# frozen_string_literal: true

require_relative "template_exporter"
require_relative "artifacts"
require_relative "mapping_actions"
require_relative "../../../lib/compression/safe_zip_reader"

module BulkImport::DiscourseMerge
  class Workbook
    CATEGORY_ACTIONS = MappingActions::CATEGORIES
    TOPIC_ACTIONS = MappingActions::TOPICS
    GROUP_ACTIONS = MappingActions::GROUPS
    STAFF_ROLES_SETTING = "Source staff roles"
    SLOTS = 100
    WIDTHS = {
      "Category Mapping" => 8,
      "New Categories" => 4,
      "Topic Exceptions" => 5,
      "Tag Rules" => 3,
      "Group Mapping" => 6,
    }.freeze

    def initialize(configuration, inventory)
      @configuration, @inventory = configuration, inventory
    end

    def library!
      require "rubyXL"
      require "rubyXL/convenience_methods"
    rescue LoadError
      raise Error, "Workbook support requires the generic_import bundle group"
    end

    def binding
      @configuration
        .data
        .slice("source_url", "destination_url", "namespace")
        .merge(
          "namespace" => @configuration.data["namespace"],
          "source_database" => @inventory.fetch("source").fetch("database"),
          "destination_database" => @inventory.fetch("destination").fetch("database"),
          "version" => 3,
        )
    end

    def paths(side)
      categories =
        @inventory.fetch(side).fetch("categories").index_by { |row| row.fetch("id").to_i }
      categories.to_h { |id, _| [id.to_s, TemplateExporter.path(id, categories)] }
    end

    def reference(value, pattern = /\[([SDN]\d+)\]\z/)
      value.to_s[pattern, 1] || raise(Error, "Choose an item from the dropdown: #{value.inspect}")
    end

    def sheet(name, headers, rows, editable = [])
      target = @book.add_worksheet(name)
      ([headers] + rows).each_with_index do |values, row|
        values.each_with_index do |value, column|
          cell = target.add_cell(row, column, value.to_s)
          cell.change_text_wrap(true)
          cell.change_fill(row.zero? ? "24476B" : editable.include?(column) ? "FFF2CC" : "FFFFFF")
          if row.zero?
            cell.change_font_color("FFFFFF")
            cell.change_font_bold(true)
          elsif editable.include?(column)
            style = @book.cell_xfs[cell.style_index].dup
            style.protection = RubyXL::Protection.new(locked: false)
            style.apply_protection = true
            cell.style_index = @book.register_new_xf(style)
          end
        end
        target.change_row_height(row, 42)
      end
      headers.each_index { |column| target.change_column_width(column, column.zero? ? 45 : 32) }
      target.sheet_protection = RubyXL::WorksheetProtection.new(sheet: true, auto_filter: false)
      target
    end

    def dropdown(target, column, name, count, allow_blank: true)
      target.data_validations ||= RubyXL::DataValidations.new
      target.data_validations << RubyXL::DataValidation.new(
        type: "list",
        sqref: "#{column}2:#{column}#{[count + 1, 2].max}",
        formula1: RubyXL::Formula.new(expression: name),
        allow_blank: allow_blank,
        show_error_message: true,
        error_style: "stop",
        error: "Select a listed choice",
      )
    end

    def export(path)
      library!
      raise Error, "Refusing to overwrite #{path}" if File.exist?(path)
      mappings =
        %w[categories.csv topics.csv new_categories.csv].to_h do |name|
          [
            name,
            CSV
              .read(@configuration.directory.join("mappings", name), headers: true)
              .map { |row| row.to_h.transform_values { |value| Artifacts.csv_decode(value) } },
          ]
        end
      group_path = @configuration.directory.join("mappings/groups.csv")
      groups =
        (
          if group_path.exist?
            CSV
              .read(group_path, headers: true)
              .map { |row| row.to_h.transform_values { |value| Artifacts.csv_decode(value) } }
          else
            GroupMapping.defaults(@inventory)
          end
        )
      source, destination = paths("source"), paths("destination")
      labels =
        source
          .to_h { |id, value| ["S#{id}", "#{value.join(" / ")} [S#{id}]"] }
          .merge(destination.to_h { |id, value| ["D#{id}", "#{value.join(" / ")} [D#{id}]"] })
      refs = destination.to_h { |id, value| [value.join(" > "), "D#{id}"] }
      mappings
        .fetch("categories.csv")
        .each do |row|
          refs[row.fetch("destination")] = "S#{row.fetch("source_category_id")}" if row.fetch(
            "action",
          ) == "copy"
        end
      additions = mappings.fetch("new_categories.csv")
      raise Error, "Workbook supports #{SLOTS} new categories" if additions.size > SLOTS
      additions.each_with_index do |row, index|
        refs[row.fetch("path")] = format("N%03d", index + 1)
      end
      SLOTS.times do |index|
        key = format("N%03d", index + 1)
        labels[
          key
        ] = "#{additions[index]&.fetch("path")&.split(" > ")&.last || "New category slot #{key[1..]}"} [#{key}]"
      end
      target = ->(value) { value.to_s.empty? ? "" : labels.fetch(refs.fetch(value)) }
      @book = RubyXL::Workbook.new
      @book.worksheets.clear
      start_here =
        sheet(
          "Start Here",
          %w[Step Instructions],
          [
            ["1", "Edit yellow cells. Keep generated identifiers and sheet names intact."],
            ["2", "Keep category preserves it. Move discussions only omits the source category."],
            [
              "3",
              "Name new categories once, then select their choices as destinations. They need not exist yet.",
            ],
            ["4", "Topic exceptions override category destinations. Category tags still apply."],
            [
              "5",
              "Custom groups can match, stay separate, merge, rename or be excluded. Permissions require review.",
            ],
            ["6", "Open Settings to choose the staff roles for newly created accounts."],
            [
              "7",
              "Save as .xlsx. Your operator validates the final plan; Review is an export-time snapshot.",
            ],
          ],
        )
      start_here.hyperlinks = RubyXL::Hyperlinks.new
      start_here.hyperlinks << RubyXL::Hyperlink.new(ref: "B7", location: "'Settings'!B2")
      settings =
        sheet(
          "Settings",
          ["Setting", "Decision", "Applies to"],
          [
            [
              STAFF_ROLES_SETTING,
              MappingActions::STAFF_ROLES.key("preserve"),
              "New accounts only. Matched accounts keep their destination roles.",
            ],
          ],
          [1],
        )
      settings.change_column_width(1, 38)
      settings.change_column_width(2, 48)
      dropdown(
        settings,
        "B",
        %("#{MappingActions::STAFF_ROLES.keys.join(",")}"),
        1,
        allow_blank: false,
      )
      category_rows =
        mappings
          .fetch("categories.csv")
          .map do |row|
            parts = row.fetch("destination").split(" > ")
            copy = row.fetch("action") == "copy"
            [
              row.fetch("source_category_id"),
              row.fetch("source_path").gsub(" > ", " / "),
              CATEGORY_ACTIONS.key(row.fetch("action")),
              copy && parts.size > 1 ? target.call(parts[0...-1].join(" > ")) : "Top level",
              (
                if copy && parts.last != source.fetch(row.fetch("source_category_id")).last
                  parts.last
                else
                  ""
                end
              ),
              target.call(
                row["topic_destination"].presence ||
                  (copy || row["action"] == "exclude" ? "" : row["destination"]),
              ).presence || "This category",
              row["add_tags"].to_s.split("|").first,
              row["notes"],
            ]
          end
      categories =
        sheet(
          "Category Mapping",
          [
            "Source ID",
            "Source category",
            "Action",
            "Parent category",
            "Rename to",
            "Discussions go to",
            "Add tag",
            "Notes",
          ],
          category_rows,
          [2, 3, 4, 5, 6, 7],
        )
      new_rows =
        SLOTS.times.map do |index|
          parts = additions[index]&.fetch("path")&.split(" > ") || []
          [
            format("N%03d", index + 1),
            parts.last,
            parts.size > 1 ? target.call(parts[0...-1].join(" > ")) : "Top level",
            additions[index]&.fetch("notes", ""),
          ]
        end
      new_categories =
        sheet("New Categories", ["Key", "Name", "Parent category", "Notes"], new_rows, [1, 2, 3])
      definitions =
        @inventory.fetch("source").fetch("categories").map { |row| row["topic_id"].to_s }.to_set
      topics =
        @inventory
          .fetch("source")
          .fetch("topics")
          .select do |row|
            row["archetype"] == "regular" && !definitions.include?(row.fetch("id").to_s)
          end
          .index_by { |row| row.fetch("id").to_s }
      titles =
        topics.to_h { |id, row| [id, "#{row["title"].presence || "Untitled discussion"} [T#{id}]"] }
      topic_rows =
        mappings
          .fetch("topics.csv")
          .map do |row|
            [
              titles[row["source_topic_id"]] || "Absent source topic [T#{row["source_topic_id"]}]",
              row["action"] == "exclude" ?
                "Exclude" :
                row["destination"].present? ? "Move discussion" : "Use category rule",
              target.call(row["destination"]),
              row["add_tags"].to_s.split("|").first,
              row["notes"],
            ]
          end
      topic_rows += Array.new(SLOTS) { ["", "Use category rule", "", "", ""] }
      exceptions =
        sheet(
          "Topic Exceptions",
          [
            "Source topic",
            "Action",
            "Destination",
            "Add tag",
            "Notes",
            "Source category",
            "Source URL",
          ],
          topic_rows,
          [0, 1, 2, 3, 4],
        )
      topic_rows.each_index do |index|
        [5, 6].each do |column|
          exceptions.add_cell(
            index + 1,
            column,
            nil,
            "IFERROR(VLOOKUP(A#{index + 2},'Topic Catalog'!$A$2:$D$#{[topics.size + 1, 2].max},#{column - 3},FALSE),\"\")",
          )
        end
      end
      tags =
        mappings
          .values
          .flatten
          .flat_map { |row| row["add_tags"].to_s.split("|") }
          .reject(&:empty?)
          .uniq
          .sort
      tag_sheet =
        sheet("Tags", ["Tag name"], tags.map { |tag| [tag] } + Array.new(SLOTS) { [""] }, [0])
      rules =
        %w[categories.csv topics.csv].flat_map do |name|
          mappings
            .fetch(name)
            .flat_map do |row|
              row["add_tags"]
                .to_s
                .split("|")
                .drop(1)
                .map do |tag|
                  [
                    name == "categories.csv" ? "Category" : "Topic",
                    (
                      if name == "categories.csv"
                        labels.fetch("S#{row["source_category_id"]}")
                      else
                        titles.fetch(row["source_topic_id"])
                      end
                    ),
                    tag,
                  ]
                end
            end
        end
      tag_rules =
        sheet(
          "Tag Rules",
          ["Apply to", "Category or topic", "Add tag"],
          rules + Array.new(SLOTS) { ["", "", ""] },
          [0, 1, 2],
        )
      %w[source destination].each do |side|
        sheet(
          "#{side.capitalize} Categories",
          %w[Category Access],
          @inventory
            .fetch(side)
            .fetch("categories")
            .map do |row|
              [
                labels.fetch("#{side == "source" ? "S" : "D"}#{row["id"]}"),
                row["read_restricted"] == "t" ? "Restricted" : "Public",
              ]
            end,
        )
      end
      sheet(
        "Topic Catalog",
        ["Topic", "Source category", "URL", "State"],
        topics.map do |id, row|
          [
            titles.fetch(id),
            labels.fetch("S#{row["category_id"]}") do
              "Missing source category (#{row["category_id"]})"
            end,
            "#{@configuration.data.fetch("source_url")}/t/#{id}",
            row["deleted_at"] ? "Deleted" : row["visible"] == "f" ? "Unlisted" : "Listed",
          ]
        end,
      )
      destination_groups =
        GroupMapping
          .custom(@inventory.fetch("destination").fetch("groups", []))
          .to_h { |row| [row.fetch("id").to_s, "#{row.fetch("name")} [DG#{row.fetch("id")}]"] }
      source_groups =
        GroupMapping
          .custom(@inventory.fetch("source").fetch("groups", []))
          .index_by { |row| row.fetch("id").to_s }
      group_rows =
        groups.map do |row|
          action =
            row["action"] == "copy" ?
              row["name"].present? ? "Rename" : "Keep separate" :
              GROUP_ACTIONS.key(row["action"])
          [
            row["source_group_id"],
            source_groups.fetch(row["source_group_id"].to_s).fetch("name"),
            action,
            (
              if row["action"] == "reuse"
                destination_groups.fetch(row["destination_group_id"].to_s)
              else
                ""
              end
            ),
            row["name"],
            row["notes"],
          ]
        end
      group_sheet =
        sheet(
          "Group Mapping",
          [
            "Source ID",
            "Source group",
            "Action",
            "Existing destination group",
            "New name",
            "Notes",
          ],
          group_rows,
          [2, 3, 4, 5],
        )
      sheet(
        "Source Groups",
        ["Custom source group"],
        source_groups.map { |id, row| ["#{row["name"]} [SG#{id}]"] },
      )
      sheet(
        "Destination Groups",
        ["Custom destination group"],
        destination_groups.values.map { |label| [label] },
      )
      sheet(
        "Review",
        ["Export-time snapshot", "Value"],
        [
          ["Source categories", source.size],
          ["New categories", additions.size],
          ["Next step", "Ask your operator to generate and review preview.md"],
        ],
      )
      planned =
        sheet(
          "Planned Categories",
          ["Key", "Category choice", "Kind", "Current name", "Parent", "Status"],
          labels.map do |key, label|
            [
              key,
              label,
              key.start_with?("D") ?
                "Existing" :
                if key.start_with?("S")
                  "Imported; see Category Mapping"
                else
                  "Proposed; see New Categories"
                end,
              key.start_with?("D") ? destination.fetch(key.delete_prefix("D")).last : "",
              (
                if key.start_with?("D")
                  destination.fetch(key.delete_prefix("D"))[0...-1].join(" / ")
                else
                  ""
                end
              ),
              key.start_with?("D") ? "Exists" : "",
            ]
          end,
        )
      labels.keys.each_with_index do |key, index|
        next if key.start_with?("D")
        if key.start_with?("N")
          range = "'New Categories'!$A$2:$D$#{SLOTS + 1}"
          lookup = ->(column) { "VLOOKUP(\"#{key}\",#{range},#{column},FALSE)" }
          name, parent = lookup.call(2), lookup.call(3)
          status = "IF(#{name}=\"\",\"Empty slot\",\"Will create\")"
        else
          range = "'Category Mapping'!$A$2:$H$#{category_rows.size + 1}"
          lookup = ->(column) { "VLOOKUP(\"#{key.delete_prefix("S")}\",#{range},#{column},FALSE)" }
          original_name = source.fetch(key.delete_prefix("S")).last.gsub('"', '""')
          name = "IF(#{lookup.call(5)}=\"\",\"#{original_name}\",#{lookup.call(5)})"
          parent = lookup.call(4)
          status = "IF(#{lookup.call(3)}=\"Keep category\",\"Will create\",#{lookup.call(3)})"
        end
        [name, parent, status].each_with_index do |formula, column|
          planned.add_cell(index + 1, column + 3, nil, "IFERROR(#{formula},\"Check mapping\")")
        end
      end
      choices =
        sheet(
          "Choices",
          %w[
            Targets
            Parents
            DiscussionTargets
            Topics
            TagNames
            TagSubjects
            DestinationGroupChoices
            ExistingCategoryChoices
          ],
          [],
        )
      lists = [
        labels.values,
        labels.values + ["Top level"],
        labels.values + ["This category"],
        titles.values,
        tags + Array.new(SLOTS, ""),
        source.keys.map { |id| labels.fetch("S#{id}") } + titles.values,
        destination_groups.values,
        destination.keys.map { |id| labels.fetch("D#{id}") },
      ]
      lists.each_with_index do |values, column|
        values = [""] if values.empty?
        values.each_with_index do |value, index|
          key = value[/\[(N\d+)\]\z/, 1]
          formula =
            if key && column < 3
              lookup = "VLOOKUP(\"#{key}\",'New Categories'!$A$2:$B$#{SLOTS + 1},2,FALSE)"
              "IFERROR(IF(#{lookup}=\"\",\"New category slot #{key[1..]}\",#{lookup})&\" [#{key}]\",\"New category slot #{key[1..]} [#{key}]\")"
            elsif column == 4
              "IF(Tags!A#{index + 2}=\"\",\"\",Tags!A#{index + 2})"
            end
          choices.add_cell(index + 1, column, formula ? nil : value, formula)
        end
        letter = (65 + column).chr
        @book.define_new_name(
          choices[0][column].value,
          "'Choices'!$#{letter}$2:$#{letter}$#{values.size + 1}",
        )
      end
      [
        [categories, "C", CATEGORY_ACTIONS.keys],
        [exceptions, "B", TOPIC_ACTIONS.keys],
        [group_sheet, "C", GROUP_ACTIONS.keys],
        [tag_rules, "A", %w[Category Topic]],
      ].each do |target_sheet, column, values|
        dropdown(target_sheet, column, "\"#{values.join(",")}\"", target_sheet.sheet_data.size - 1)
      end
      [
        [categories, "D", "Parents"],
        [
          categories,
          "F",
          'IF($C2="Use existing category",ExistingCategoryChoices,DiscussionTargets)',
        ],
        [categories, "G", "TagNames"],
        [new_categories, "C", "Parents"],
        [exceptions, "A", "Topics"],
        [exceptions, "C", "Targets"],
        [exceptions, "D", "TagNames"],
        [tag_rules, "B", "TagSubjects"],
        [tag_rules, "C", "TagNames"],
        [group_sheet, "D", "DestinationGroupChoices"],
      ].each do |target_sheet, column, name|
        dropdown(target_sheet, column, name, target_sheet.sheet_data.size - 1)
      end
      [categories, new_categories, group_sheet, planned].each do |target_sheet|
        target_sheet.cols.each { |range| range.hidden = true if range.min == 1 && range.max == 1 }
      end
      choices.state = "hidden"
      metadata = sheet("Metadata", ["Binding"], [[JSON.generate(binding)]])
      metadata.state = "veryHidden"
      Artifacts.write(path, @book.stream.string, replace: false)
    end

    def read(path)
      library!
      @path = path
      raise Error, "Workbook is too large; use CSV" if File.size(path) > 64 * 1024 * 1024
      bytes = File.binread(path)
      Zip::File.open_buffer(bytes) do |zip|
        reader =
          Compression::SafeZipReader.new(
            zip,
            max_entries: 10_000,
            max_total_bytes: 512 * 1024 * 1024,
          )
        reader.validate!
        reader.entries.each do |entry|
          if entry.name.match?(%r{vbaProject|embeddings/}i)
            raise Error, "Macro-enabled workbooks are unsupported"
          end
          next if entry.directory?
          data = reader.read_entry(entry, max_bytes: 512 * 1024 * 1024)
          if entry.name == "[Content_Types].xml" && data.include?("macroEnabled")
            raise Error, "Macro-enabled workbooks are unsupported"
          end
          if entry.name.end_with?(".xml", ".rels") && data.match?(/<!DOCTYPE|<!ENTITY/i)
            raise Error, "Workbook XML entities are unsupported"
          end
        end
      end
      @book = RubyXL::Parser.parse_buffer(bytes)
      metadata = @book["Metadata"]
      raise Error, "Missing workbook metadata" unless metadata && metadata[1] && metadata[1][0]
      actual = JSON.parse(cell_text(metadata[1][0]))
      raise Error, "Invalid workbook binding" unless actual.is_a?(Hash)
      expected = binding.merge("version" => actual["version"])
      unless [1, 2, 3].include?(actual["version"]) && actual == expected
        raise Error, "Workbook belongs to another source/destination project"
      end
      if actual["version"] >= 2 && !@book["Group Mapping"]
        raise Error, "Group Mapping sheet is required"
      end
      staff_roles = actual["version"] >= 3 ? read_staff_roles : "preserve"
      compile.merge("source_staff_roles" => staff_roles)
    rescue Error, Zip::Error, JSON::ParserError, Compression::SafeZipReader::Error => error
      raise if error.message.start_with?("#{path}:")
      raise Error, "#{path}: #{error.message}"
    end

    def read_staff_roles
      settings = @book["Settings"] || raise(Error, "Settings sheet is required")
      location = "#{@path}: Settings!B2"
      if cell_text(settings[1]&.[](0)) != STAFF_ROLES_SETTING
        raise Error, "#{location}: missing #{STAFF_ROLES_SETTING} setting"
      end
      decision = settings[1][1]
      role = MappingActions::STAFF_ROLES[cell_text(decision)] unless decision&.formula
      role || raise(Error, "#{location}: choose a listed #{STAFF_ROLES_SETTING} option")
    end

    def rows(name)
      target = @book[name] || raise(Error, "Missing workbook sheet: #{name}")
      target
        .sheet_data
        .rows
        .drop(1)
        .each_with_index
        .filter_map do |row, index|
          cells = Array.new(WIDTHS.fetch(name)) { |column| row && row[column] }
          if cells.any? { |cell| cell&.formula }
            raise Error, "#{name}, row #{index + 2}: formulas are not allowed in mapping cells"
          end
          values = cells.map { |cell| cell_text(cell).strip }
          ["#{@path}: #{name}, row #{index + 2}", values] if values.any?(&:present?)
        end
    end

    def at(location)
      yield
    rescue Error, KeyError => error
      raise if error.message.start_with?("#{@path}:")
      raise Error, "#{location}: #{error.message}"
    end

    def compile
      source = paths("source")
      nodes = paths("destination").to_h { |id, path| ["D#{id}", path] }
      category_rows = rows("Category Mapping")
      category_rows.each do |location, (id, _, action, parent, rename, *_)|
        at(location) do
          raise Error, "Unknown category action #{action}" unless CATEGORY_ACTIONS.key?(action)
          if action == "Keep category"
            raise Error, "Duplicate source category #{id}" if nodes.key?("S#{id}")
            nodes["S#{id}"] = [parent, rename.presence || source.fetch(id).last, location]
          end
        end
      end
      additions = rows("New Categories")
      seen = Set.new
      additions.each do |location, (key, name, parent, _)|
        at(location) do
          unless key.match?(/\AN\d+\z/) && seen.add?(key)
            raise Error, "Invalid or duplicate new category key #{key}"
          end
          nodes[key] = [parent, name, location] if name.present?
        end
      end
      resolve =
        lambda do |key, ancestry = Set.new|
          raise Error, "Category parents contain a cycle" if ancestry.include?(key)
          value =
            nodes.fetch(key) { raise Error, "Unknown, empty or omitted category target: #{key}" }
          return value if key.start_with?("D")
          parent, name, location = value
          at(location) do
            raise Error, "Invalid category name" if name.blank? || name.include?(">")
            (parent == "Top level" ? [] : resolve.call(reference(parent), ancestry | [key])) +
              [name]
          end
        end
      target = ->(label) { resolve.call(reference(label)).join(" > ") }
      categories =
        category_rows.map do |location, (id, _, action, _, _, selected, tag, notes)|
          at(location) do
            operation = CATEGORY_ACTIONS.fetch(action)
            {
              "source_category_id" => id,
              "source_path" => source.fetch(id).join(" > "),
              "action" => operation,
              "destination" =>
                operation == "copy" ?
                  resolve.call("S#{id}").join(" > ") :
                  operation == "exclude" ? "" : target.call(selected),
              "topic_destination" =>
                operation == "copy" && selected != "This category" ? target.call(selected) : "",
              "add_tags" => tag,
              "notes" => notes,
              "_location" => location,
            }
          end
        end
      new_categories =
        additions.filter_map do |location, (key, name, _, notes)|
          at(location) do
            if name.present?
              { "path" => resolve.call(key).join(" > "), "notes" => notes, "_location" => location }
            end
          end
        end
      inventory_topics =
        @inventory.fetch("source").fetch("topics").index_by { |row| row.fetch("id").to_s }
      topics =
        rows("Topic Exceptions").filter_map do |location, (label, action, destination, tag, notes)|
          at(location) do
            if label.blank?
              if destination.present? || tag.present? || notes.present? ||
                   !["", "Use category rule"].include?(action)
                raise Error, "Choose a source topic"
              end
              next
            end
            id = reference(label, /\[T(\d+)\]\z/)
            raise Error, "Unknown topic action" unless TOPIC_ACTIONS.key?(action)
            raise Error, "Choose a destination" if action == "Move discussion" && destination.blank?
            if action == "Use category rule" && destination.present?
              raise Error, "Select Move discussion to override its destination"
            end
            {
              "source_topic_id" => id,
              "source_category_id" => inventory_topics[id]&.fetch("category_id").to_s,
              "action" => TOPIC_ACTIONS.fetch(action),
              "destination" =>
                destination.present? && action != "Exclude" ? target.call(destination) : "",
              "add_tags" => tag,
              "notes" => notes,
              "_location" => location,
            }
          end
        end
      rows("Tag Rules").each do |location, (scope, label, tag)|
        at(location) do
          raise Error, "Choose a tag" if tag.blank?
          unless tag
                   .split("|")
                   .map(&:strip)
                   .reject(&:empty?)
                   .all? { |value| value.match?(/\A[\p{L}\p{N}_-]+\z/) }
            raise Error, "Invalid tag"
          end
          row =
            if scope == "Category"
              id = reference(label, /\[S(\d+)\]\z/)
              categories.find { |item| item["source_category_id"] == id }
            elsif scope == "Topic"
              id = reference(label, /\[T(\d+)\]\z/)
              raise Error, "Choose a source topic" unless inventory_topics.key?(id)
              topics.find { |item| item["source_topic_id"] == id } ||
                {
                  "source_topic_id" => id,
                  "source_category_id" => inventory_topics.fetch(id).fetch("category_id"),
                  "action" => "inherit",
                  "destination" => "",
                  "add_tags" => "",
                  "_location" => location,
                }.tap { |item| topics << item }
            end
          raise Error, "Choose a source category or topic" unless row
          row["add_tags"] = [row["add_tags"].presence, tag].compact.join("|")
          row["_tag_location"] = location
        end
      end
      result = {
        "categories.csv" => categories,
        "topics.csv" => topics,
        "new_categories.csv" => new_categories,
      }
      if @book["Group Mapping"]
        result["groups.csv"] = rows(
          "Group Mapping",
        ).map do |location, (id, _, action, destination, name, notes)|
          at(location) do
            operation = GROUP_ACTIONS.fetch(action) { raise Error, "Choose a group action" }
            if operation == "reuse"
              raise Error, "Leave New name empty" if name.present?
              destination = reference(destination, /\[DG(\d+)\]\z/)
            else
              raise Error, "Leave destination empty" if destination.present?
              raise Error, "Use Rename with a new name" if (action == "Rename") != name.present?
            end
            {
              "source_group_id" => id,
              "action" => operation,
              "destination_group_id" => destination,
              "name" => name,
              "notes" => notes,
              "_location" => location,
            }
          end
        end
      end
      result
    end

    private

    def cell_text(cell)
      return "" unless cell
      # An empty text cell can have a string type but no stored value to decode.
      return "" if cell.datatype == RubyXL::DataType::RAW_STRING && cell.raw_value.nil?
      cell.value.to_s
    end
  end
end
