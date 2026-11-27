# frozen_string_literal: true

require_relative "prepared_uploads"

module BulkImport::DiscourseMerge
  class PreuploadedMedia
    TEXT_COLUMNS = {
      "posts" => %w[raw cooked excerpt],
      "post_localizations" => %w[raw cooked],
      "topics" => %w[excerpt],
      "topic_localizations" => %w[excerpt],
      "categories" => %w[description],
      "category_localizations" => %w[description],
      "tags" => %w[description],
      "tag_localizations" => %w[description],
      "topic_links" => %w[url],
      "user_profiles" => %w[bio_raw bio_cooked],
      "groups" => %w[bio_raw bio_cooked],
      "post_revisions" => %w[modifications],
      "badges" => %w[description long_description],
    }.freeze

    def self.open(plan, directory)
      path = directory.join(PreparedUploads::FILE)
      unless Digest::SHA256.file(path).hexdigest == plan.dig("upload_policy", "receipt_sha256")
        raise Error, "Prepared upload receipts differ from the reviewed plan"
      end
      PreparedUploads.open(path) { |state| yield new(state, plan) }
    end

    def initialize(state, plan)
      @state, @plan = state, plan
      @target = state.target
    end

    def attributes(kind, result)
      attrs = { "url" => result.fetch("url"), "etag" => result.fetch("etag") }
      if kind == "optimized_images"
        attrs.merge!("sha1" => result.fetch("sha1"), "filesize" => result.fetch("size"))
      end
      attrs
    end

    def destination_receipt(kind, id)
      @state.receipt("destination", kind, id)
    end

    def each_batch(side)
      buffer = []
      @state.each_receipt(side) do |kind, id, input, result|
        if buffer.any? && (buffer.first[0] != kind || buffer.size == 1000)
          yield buffer
          buffer = []
        end
        buffer << [kind, id, input, result]
      end
      yield buffer if buffer.any?
    end

    def receipt(side, kind, id)
      @state.receipt(side, kind, id) ||
        raise(Error, "Missing prepared record: #{side} #{kind} #{id}")
    end

    def source_result(kind, id, reused_id)
      if @plan.dig("upload_policy", "preserve_destination_uploads")
        reviewed_id = @plan.fetch("upload_policy").fetch("retained_ids").fetch(kind)[id.to_s]
        unless reviewed_id == reused_id
          raise Error, "Retained destination ID changed for #{kind} #{id}"
        end
        return if reviewed_id
      end
      receipt("source", kind, id)
    end

    def map_urls(map, side, old_url, result, final_url)
      origin = @plan.fetch("policy").fetch("#{side}_url")
      old = URI.parse(Media.remote_url(old_url, origin))
      path = old.path
      bases = @plan.dig("upload_policy", "media_origins", side) || {}
      aliases = [old_url, old.to_s, old.to_s.sub(/\Ahttps?:/, "")]
      aliases.concat(["http:#{old_url}", "https:#{old_url}"]) if old_url.start_with?("//")
      if old_url.start_with?("/") && !old_url.start_with?("//")
        [bases["base_url"], bases["cdn_url"]].compact_blank.each do |base|
          aliases << File.join(base, path)
        end
      end
      if bases["s3_base_url"].present? && bases["s3_cdn_url"].present?
        base = Media.remote_url(bases["s3_base_url"], origin).delete_suffix("/") + "/"
        if old.to_s.start_with?(base)
          aliases << File.join(bases["s3_cdn_url"], old.to_s.delete_prefix(base))
        end
      end
      if result && result.fetch("secure")
        %w[secure-uploads secure-media-uploads].each do |route|
          relative = "/#{route}/#{path.delete_prefix("/")}"
          aliases.concat([relative, Media.remote_url(relative, origin)])
        end
      end
      delivery =
        if result
          Media.delivery_url(
            final_url,
            result.fetch("secure"),
            @target,
            @plan.dig("policy", "destination_url"),
          )
        else
          final_url
        end
      aliases +=
        aliases.filter_map do |url|
          url.sub(/\Ahttps?:/, "") if url.start_with?("https://", "http://")
        end
      aliases.compact.uniq.each do |url|
        next if url == delivery
        if map.key?(url) && map[url] != delivery
          raise Error, "Conflicting prepared media URL: #{url}"
        end
        map[url] = delivery
      end
    end

    # Apply reviewed storage changes before taking the merger's destination preservation
    # baseline. Existing post and upload IDs and all non-media fields stay in place.
    def update_destination!
      return if @plan.dig("upload_policy", "preserve_destination_uploads")
      connection = ActiveRecord::Base.connection
      urls = {}
      connection.transaction do
        each_batch("destination") do |batch|
          changes =
            batch.filter_map do |kind, id, input, result|
              attrs = attributes(kind, result)
              map_urls(urls, "destination", input.fetch("url"), result, attrs.fetch("url"))
              unless attrs.all? { |key, value| input[key].to_s == value.to_s }
                attrs.merge("id" => id)
              end
            end
          update_rows(connection, batch.first.first, "id", changes) if changes.any?
        end
        next if urls.empty?
        dest = @plan.fetch("policy").fetch("destination_url")
        refs =
          References.new(
            source_host: URI.parse(dest).host,
            destination_host: URI.parse(dest).host,
            source_base_url: dest,
            destination_base_url: dest,
            topics: {
            },
            categories: {
            },
            media_origins: @plan.dig("upload_policy", "media_origins", "destination") || {},
            upload_mode: "prepared_destination",
            media_urls: urls,
            verify_media: true,
          )
        TEXT_COLUMNS.each do |table, candidates|
          next unless connection.data_source_exists?(table)
          columns = candidates & connection.columns(table).map(&:name)
          next if columns.empty?
          pk = connection.primary_key(table)
          next unless pk.is_a?(String)
          last = -2**63
          loop do
            rows =
              connection.select_all(
                "SELECT #{([pk] + columns).join(",")} FROM #{table} WHERE #{pk} > #{Integer(last)} ORDER BY #{pk} LIMIT 1000",
              ).to_a
            break if rows.empty?
            last = rows.last.fetch(pk)
            changes =
              rows.filter_map do |row|
                rewritten =
                  row
                    .slice(*columns)
                    .to_h do |column, value|
                      [column, refs.rewrite(value, cooked: column.include?("cooked"))]
                    end
                next if rewritten == row.slice(*columns)
                if table == "topic_links"
                  rewritten["domain"] = URI.parse(rewritten.fetch("url")).host
                end
                rewritten.merge(pk => row.fetch(pk))
              end
            update_rows(connection, table, pk, changes) if changes.any?
          end
        end
      end
    end

    private

    def update_rows(connection, table, pk, rows)
      fields = rows.first.keys - [pk]
      types = connection.schema_cache.columns_hash(table)
      definition = ([pk] + fields).map { |name| "#{name} #{types.fetch(name).sql_type}" }.join(",")
      assignments = fields.map { |name| "#{name}=changes.#{name}" }.join(",")
      relation = connection.exec_update(<<~SQL)
        UPDATE #{table} AS target SET #{assignments}
        FROM jsonb_to_recordset(CAST(#{connection.quote(rows.to_json)} AS jsonb)) AS changes(#{definition})
        WHERE target.#{pk}=changes.#{pk}
      SQL
      raise Error, "Incomplete destination media update in #{table}" unless relation == rows.length
    end
  end
end
