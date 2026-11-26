# frozen_string_literal: true

require "csv"
require "tmpdir"
require_relative "configuration"
require_relative "group_mapping"

module BulkImport::DiscourseMerge
  class TemplateExporter
    CATEGORY_HEADERS = %w[
      source_category_id
      source_path
      action
      destination
      topic_destination
      add_tags
      notes
      source_access
      live_discussions
    ].freeze
    TOPIC_HEADERS = %w[
      source_topic_id
      source_category_id
      action
      destination
      add_tags
      notes
      source_title
      source_url
      source_state
    ].freeze

    def self.path(id, categories, seen = Set.new)
      raise Error, "Invalid category ancestry: #{id}" if seen.include?(id) || !categories.key?(id)
      category = categories.fetch(id)
      parent = category["parent_category_id"]
      (parent ? path(parent.to_i, categories, seen | [id]) : []) + [category.fetch("name")]
    end

    def initialize(configuration, inventory)
      @configuration, @inventory = configuration, inventory
    end

    def export(topic_categories: [], parent_path: "", excluded_category_ids: [])
      directory = @configuration.directory.join("mappings")
      if directory.exist? || @configuration.directory.join("mappings.xlsx").exist?
        raise Error,
              "Mapping directory already exists; preserve customer edits or select a new project"
      end
      source =
        @inventory.fetch("source").fetch("categories").index_by { |row| row.fetch("id").to_i }
      destination =
        @inventory.fetch("destination").fetch("categories").index_by { |row| row.fetch("id").to_i }
      unless (excluded_category_ids - source.keys).empty?
        raise Error, "Unknown excluded category IDs: #{excluded_category_ids - source.keys}"
      end
      parent_parts = parent_path.to_s.split(/\s*>\s*/).map(&:strip)
      descriptions = source.values.map { |row| row["topic_id"].to_i }.to_set
      discussion_counts =
        @inventory
          .fetch("source")
          .fetch("topics")
          .each_with_object(Hash.new(0)) do |row, counts|
            if row["archetype"] == "regular" && row["deleted_at"].nil? && row["visible"] == "t" &&
                 !descriptions.include?(row["id"].to_i)
              counts[row["category_id"].to_i] += 1
            end
          end
      Dir.mktmpdir(".mappings-", @configuration.directory) do |staging|
        templates = Pathname.new(staging).join("mappings")
        templates.mkdir(0o700)
        write_templates(
          templates,
          source,
          destination,
          parent_parts,
          excluded_category_ids,
          discussion_counts,
          descriptions,
          topic_categories,
        )
        if directory.exist? || @configuration.directory.join("mappings.xlsx").exist?
          raise Error, "Mapping decisions already exist; use a new project to generate templates"
        end
        File.rename(templates, directory)
      end
    end

    def write(path, headers, rows)
      contents =
        CSV.generate(write_headers: true, headers: headers) do |csv|
          rows.each do |row|
            csv << headers.map do |header|
              row[header].nil? ? nil : Artifacts.csv_encode(row[header])
            end
          end
        end
      Artifacts.write(path, contents)
    end

    private

    def write_templates(
      directory,
      source,
      destination,
      parent_parts,
      excluded_category_ids,
      discussion_counts,
      descriptions,
      topic_categories
    )
      write(
        directory.join("categories.csv"),
        CATEGORY_HEADERS,
        source.map do |id, _|
          {
            "source_category_id" => id,
            "source_path" => self.class.path(id, source).join(" > "),
            "source_access" => source.fetch(id)["read_restricted"] == "t" ? "restricted" : "public",
            "live_discussions" => discussion_counts[id],
            "action" => excluded_category_ids.include?(id) ? "exclude" : "copy",
            "destination" =>
              (
                if excluded_category_ids.include?(id)
                  nil
                else
                  (parent_parts + self.class.path(id, source)).join(" > ")
                end
              ),
          }
        end,
      )
      topics =
        @inventory
          .fetch("source")
          .fetch("topics")
          .filter_map do |row|
            if row["archetype"] == "private_message" || descriptions.include?(row["id"].to_i) ||
                 !topic_categories.include?(row["category_id"].to_i)
              next
            end
            {
              "source_topic_id" => row["id"],
              "source_category_id" => row["category_id"],
              "action" => "include",
              "source_title" => row["title"],
              "source_state" =>
                row["deleted_at"] ? "deleted" : row["visible"] == "f" ? "unlisted" : "listed",
              "source_url" =>
                "#{@configuration.data.fetch("source_url").delete_suffix("/")}/t/#{row["id"]}",
            }
          end
      write(directory.join("topics.csv"), TOPIC_HEADERS, topics)
      existing_paths = destination.keys.map { |id| self.class.path(id, destination).join(" > ") }
      parents =
        (1..parent_parts.size).filter_map do |depth|
          path = parent_parts.first(depth).join(" > ")
          { "path" => path } if existing_paths.exclude?(path)
        end
      write(directory.join("new_categories.csv"), %w[path notes], parents)
      write(
        directory.join("destinations.csv"),
        %w[destination_category_id path access],
        destination.map do |id, row|
          {
            "destination_category_id" => id,
            "path" => self.class.path(id, destination).join(" > "),
            "access" => row["read_restricted"] == "t" ? "restricted" : "public",
          }
        end,
      )
      write(
        directory.join("groups.csv"),
        %w[source_group_id action name destination_group_id notes],
        GroupMapping.defaults(@inventory),
      )
      Configuration.write(@configuration.directory.join("inventory.json"), @inventory)
    end
  end
end
