# frozen_string_literal: true

module BulkImport::DiscourseMerge
  # Stream the destination once. Only the incoming inventory and its matches stay in memory.
  class RetainedMedia
    attr_reader :source, :reuse, :summary

    def self.scan(inventory, target)
      source = {}
      inventory.connect("source") do |pg|
        pg.exec("BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY")
        PreparedUploads::TABLES.each do |table, columns|
          source[table] = pg.exec("SELECT #{columns.join(",")} FROM #{table} ORDER BY id").to_a
        end
      end
      inventory.connect("destination") do |pg|
        pg.exec("BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY")
        new(source, target) do |table, columns|
          SourceRows.to_enum(:each, pg, "SELECT #{columns.join(",")} FROM #{table} ORDER BY id")
        end
      end
    end

    def initialize(source, target)
      prefix = target.dig("read_prefixes", "destination")
      raise Error, "Set the retained destination S3 prefix" if prefix.blank?
      uri = URI.parse(prefix)
      bucket = Regexp.escape(uri.host)
      folder = Regexp.escape(uri.path.delete_suffix("/"))
      roots = { "uploads" => "original", "optimized_images" => "optimized" }
      patterns =
        roots.transform_values do |kind|
          %r{\A(?:https:)?//#{bucket}\.s3(?:[.-](?:dualstack\.)?[a-z0-9-]+)?\.amazonaws\.com(?:\.cn)?#{folder}/#{kind}/\d+X/(?:[a-f\d]/)*[\w-][\w.-]*\z}
        end

      @source = source
      @reuse = { "uploads" => {}, "optimized_images" => {} }
      @originals = source.fetch("uploads").index_by { |row| Integer(row.fetch("id")) }
      @by_sha1 =
        @originals
          .filter_map { |id, row| row if id.positive? && row["sha1"].present? }
          .index_by { |r| r["sha1"] }
      retained = {}
      fingerprints = {}
      PreparedUploads::TABLES.each do |table, columns|
        variants = source_variants if table == "optimized_images"
        count = 0
        digest = Digest::SHA256.new
        yield(table, columns).each do |row|
          id = Integer(row.fetch("id"))
          digest << JSON.generate(row.values_at(*columns)) << "\n"
          if id.positive?
            unless patterns.fetch(table).match?(row.fetch("url"))
              raise Error, "Unexpected retained destination URL for #{table} #{id}: #{row["url"]}"
            end
            count += 1
          end
          incoming =
            table == "uploads" ? matching_original(row, id) : matching_variant(row, variants)
          @reuse.fetch(table)[Integer(incoming.fetch("id"))] = id if incoming
        end
        retained[table] = count
        fingerprints[table] = digest.hexdigest
      end

      @summary = {
        "destination" => retained,
        "destination_sha256" => fingerprints,
        "source_sha256" =>
          PreparedUploads::TABLES.to_h do |table, columns|
            digest = Digest::SHA256.new
            source
              .fetch(table)
              .each { |row| digest << JSON.generate(row.values_at(*columns)) << "\n" }
            [table, digest.hexdigest]
          end,
        "reused_originals" => @reuse["uploads"].keys.count(&:positive?),
        "reused_thumbnails" => @reuse["optimized_images"].size - @builtin_matches,
        "builtin_thumbnails" => @builtin_matches,
        "additional_thumbnails" =>
          source
            .fetch("optimized_images")
            .count do |row|
              reused?("uploads", row["upload_id"]) && !reused?("optimized_images", row["id"])
            end,
        "staged" =>
          PreparedUploads::TABLES.keys.to_h do |table|
            [
              table,
              source
                .fetch(table)
                .count { |row| Integer(row["id"]).positive? && !reused?(table, row["id"]) },
            ]
          end,
      }
    end

    def reused?(table, id)
      @reuse.fetch(table).key?(Integer(id))
    end

    def parent(id)
      @originals.fetch(Integer(id)) if reused?("uploads", id)
    end

    private

    def matching_original(row, id)
      if id.positive? && (row.fetch("secure") != "f" || row["access_control_post_id"])
        raise Error, "Cannot retain protected destination upload #{id}"
      end
      incoming = id.positive? ? @by_sha1[row["sha1"]] : @originals[id]
      return unless incoming
      Media.validate_reuse!(incoming, row)
      if incoming["secure"] != "f" || incoming["access_control_post_id"] ||
           incoming["original_sha1"] != row["original_sha1"] || incoming["filesize"].nil? ||
           (id.negative? && incoming["url"] != row["url"])
        raise Error, "Inconsistent retained upload identity or permissions for #{id}"
      end
      incoming
    end

    def source_variants
      @builtin_matches = 0
      source
        .fetch("optimized_images")
        .each_with_object({}) do |row, variants|
          parent = @reuse.fetch("uploads")[Integer(row.fetch("upload_id"))]
          variants[[parent.to_s, *row.values_at("width", "height", "extension")]] = row if parent
        end
    end

    def matching_variant(row, variants)
      incoming = variants[row.values_at("upload_id", "width", "height", "extension")]
      return unless incoming
      if Integer(incoming.fetch("upload_id")).negative?
        # Core owns these negative-ID assets. The restored versions can have different pixels.
        @builtin_matches += 1
      elsif incoming.values_at("sha1", "filesize", "version") !=
            row.values_at("sha1", "filesize", "version")
        raise Error, "Conflicting retained thumbnail metadata for #{incoming["id"]}"
      end
      incoming
    end
  end
end
