# frozen_string_literal: true

require "securerandom"
require "concurrent/atomic/semaphore"
require_relative "inventory"
require_relative "support"
require_relative "retained_media"
require_relative "upload_diagnostics"

module BulkImport::DiscourseMerge
  # A closed SQLite database (with rollback journaling) is also the portable plan input.
  class PreparedUploads
    include LocalUploadFiles

    FILE = "prepared-uploads.sqlite3"
    def self.path_for(configuration)
      name =
        configuration.preserve_destination_uploads? ? "prepared-incoming-uploads.sqlite3" : FILE
      configuration.directory.join(name)
    end

    attr_reader :retained

    ORIGINAL = %w[
      id
      url
      etag
      sha1
      filesize
      secure
      original_sha1
      original_filename
      extension
      access_control_post_id
    ].freeze
    IMAGE = %w[id url etag sha1 filesize upload_id width height extension version].freeze
    TABLES = { "uploads" => ORIGINAL, "optimized_images" => IMAGE }.freeze

    class ApprovedOriginals
      FILE = "approved-originals.json"
      attr_reader :checksum

      def initialize(directory, target)
        @entries = {}
        path = directory.join(FILE)
        return unless path.exist?

        contents = path.binread
        manifest = JSON.parse(contents)
        target_uri = "s3://#{target.fetch("bucket")}/#{target.fetch("prefix")}"
        unless manifest.fetch("status") == "approved" &&
                 manifest.fetch("review_target") == target_uri &&
                 manifest["destination_read_prefix"] == target.dig("read_prefixes", "destination")
          raise Error, "Approved originals do not match the configured S3 target and read prefix"
        end
        manifest
          .fetch("entries")
          .each do |entry|
            identity = [entry.fetch("side"), entry.fetch("id")]
            unless %w[source destination].include?(identity.first) &&
                     identity.last.is_a?(Integer) && identity.last.positive? &&
                     !@entries.key?(identity) && entry.fetch("sha256").match?(/\A[0-9a-f]{64}\z/)
              raise Error, "Invalid or duplicate approved original #{identity.join(" ")}"
            end
            @entries[identity] = entry
          end
        @checksum = Digest::SHA256.hexdigest(contents)
      end

      def approved?(side, id)
        @entries.key?([side, Integer(id)])
      end

      def source_ids
        @entries.keys.filter_map { |side, id| id if side == "source" }
      end

      def digest_for(side, id, relative, recorded_sha1, size)
        entry = @entries[[side, Integer(id)]]
        return unless entry
        unless entry.values_at("relative_key", "recorded_sha1", "size") ==
                 [relative, recorded_sha1, size] && size
          raise Error, "Approved original no longer matches the restored upload #{side} #{id}"
        end
        entry.fetch("sha256")
      end
    end

    def self.open(path, readonly: true)
      require "sqlite3"
      raise Error, "Run prepare-uploads first" if readonly && !path.file?
      File.open(path, File::WRONLY | File::CREAT, 0o600, &:close) unless readonly
      db = SQLite3::Database.new(path.to_s, readonly: readonly)
      yield new(db)
    ensure
      db&.close
    end

    def initialize(db)
      @db = db
      # S3 checks can overlap freely. Image workers also fork and parallelize each resize.
      @thumbnail_slots = Concurrent::Semaphore.new(4)
    end

    def prepare!(
      configuration,
      store,
      progress,
      workers:,
      inventory: Inventory.new(configuration),
      check_only: false
    )
      @db.execute_batch(<<~SQL)
        CREATE TABLE IF NOT EXISTS metadata (name TEXT PRIMARY KEY, value TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS receipts (side TEXT, kind TEXT, id INTEGER, input TEXT NOT NULL, result TEXT NOT NULL, generation TEXT NOT NULL,
          PRIMARY KEY(side,kind,id)) WITHOUT ROWID;
      SQL
      preserve = configuration.data.fetch("preserve_destination_uploads", false)
      origins = configuration.data.values_at("source_url", "destination_url")
      identity =
        JSON.generate(
          (
            if preserve
              [origins, "preserve_destination_uploads", store.target]
            else
              [origins, store.target]
            end
          ),
        )
      approvals = ApprovedOriginals.new(configuration.directory, store.target)
      previous = @db.get_first_value("SELECT value FROM metadata WHERE name='target'")
      if previous && previous != identity
        raise Error, "Prepared upload target or forum origins changed; use a fresh project"
      end
      @db.execute("INSERT OR REPLACE INTO metadata VALUES ('target',?)", [identity])
      @db.execute("DELETE FROM metadata WHERE name='complete'")
      generation = SecureRandom.uuid
      if preserve
        @retained = RetainedMedia.scan(inventory, store.target)
        progress.start("local upload verification") if progress.respond_to?(:start)
        verify_retained_inputs!(configuration, approvals)
        progress.say(
          "Destination records retained from SQL: #{@retained.summary.fetch("destination")}",
        )
      end
      progress.start("hosted upload verification and transfer") if progress.respond_to?(:start)
      store.check!
      failures = 0
      counts = Hash.new(0)
      each_input_batch(
        configuration,
        inventory,
        store.target,
      ) do |side, table, columns, rows, root, read_prefix|
        if table == "optimized_images" && GlobalSetting.enable_vips_image_processing
          # Linux terminates the image worker when its spawning thread exits.
          # Start it on the coordinator before the short-lived batch threads run.
          DiscourseVips.version
        end
        items =
          rows.map do |row|
            if table == "optimized_images"
              parent =
                retained_parent(row["upload_id"]) ||
                  receipt(side, "uploads", row.fetch("upload_id"))
            end
            [row, parent, receipt(side, table, row.fetch("id"))]
          end
        queue = Queue.new
        items.each { |item| queue << item }
        queue.close
        results =
          [workers, items.size].min
            .times
            .map do
              Thread.new do
                batch = []
                while (item = queue.pop)
                  row, parent, previous_row = item
                  begin
                    if table == "optimized_images" &&
                         (!parent || (!parent["retained"] && parent["generation"] != generation))
                      raise Error, "parent upload #{row["upload_id"]} is missing"
                    end
                    if side == "destination" && !root && !read_prefix
                      check_hosted_key!(row.fetch("url"), table, store.target)
                    end
                    result, status =
                      transfer(
                        store,
                        root,
                        read_prefix,
                        table,
                        row,
                        parent,
                        previous_row,
                        side,
                        approvals,
                        check_only,
                      )
                    batch << [row, result, status]
                  rescue StandardError => error
                    batch << [row, nil, error.message]
                  end
                end
                batch
              end
            end
            .flat_map(&:value)
        @db.transaction do
          results.each do |row, result, status|
            if result
              @db.execute(
                "INSERT OR REPLACE INTO receipts VALUES (?,?,?,?,?,?)",
                [
                  side,
                  table,
                  row.fetch("id"),
                  JSON.generate(row.values_at(*columns)),
                  JSON.generate(result),
                  generation,
                ],
              )
              counts[status] += 1
              if check_only && table == "uploads" && status == "missing"
                progress.say(
                  "Missing target original #{row.fetch("id")}: #{result.fetch("relative")}",
                )
              end
            else
              failures += 1
              progress.say("Missing or unverified #{side} #{table} #{row.fetch("id")}: #{status}")
            end
          end
        end
        progress.say("#{side} #{table}: #{counts}, #{failures} unverified")
        failures
      end
      if failures.positive?
        raise Error,
              "#{failures} unverified uploads; correct the reported files and rerun prepare-uploads"
      end
      return counts if check_only
      @db.transaction do
        if @retained
          @db.execute(
            "INSERT OR REPLACE INTO metadata VALUES ('retained',?)",
            [JSON.generate(@retained.summary)],
          )
        end
        @db.execute("DELETE FROM metadata WHERE name='approved_originals_sha256'")
        if approvals.checksum
          @db.execute(
            "INSERT INTO metadata VALUES ('approved_originals_sha256',?)",
            [approvals.checksum],
          )
        end
        @db.execute("DELETE FROM receipts WHERE generation <> ?", [generation])
        progress.say("Removed #{@db.changes} surplus preparation records")
        @db.execute("INSERT INTO metadata VALUES ('complete',?)", [generation])
      end
    end

    def receipt(side, table, id)
      row =
        @db.get_first_row(
          "SELECT result,generation,input FROM receipts WHERE side=? AND kind=? AND id=?",
          [side, table, id],
        )
      JSON.parse(row[0]).merge("generation" => row[1], "input" => JSON.parse(row[2])) if row
    end

    def validate!(inventory, origins:, configuration: nil)
      unless identity.first == origins
        raise Error, "Site URLs changed since upload preparation; use the matching project"
      end
      unless @db.get_first_value("SELECT value FROM metadata WHERE name='complete'")
        raise Error, "Incomplete upload preparation; rerun prepare-uploads"
      end
      if configuration
        if configuration.data.key?("preupload_locations")
          configuration.check_preupload_locations!(target)
        end
        approved = ApprovedOriginals.new(configuration.directory, target)
        unless approved.checksum ==
                 @db.get_first_value(
                   "SELECT value FROM metadata WHERE name='approved_originals_sha256'",
                 )
          raise Error, "Approved originals changed since preparation"
        end
        unless configuration.preserve_destination_uploads? ==
                 (identity[1] == "preserve_destination_uploads")
          raise Error, "Destination preservation policy changed; rerun prepare-uploads"
        end
      end
      if identity[1] == "preserve_destination_uploads"
        @retained =
          RetainedMedia.new(inventory.fetch("source"), target) do |table, _|
            inventory.fetch("destination").fetch(table)
          end
        unless @retained.summary ==
                 JSON.parse(@db.get_first_value("SELECT value FROM metadata WHERE name='retained'"))
          raise Error, "Retained media inventory changed; rerun prepare-uploads"
        end
      end
      (@retained ? %w[source] : %w[source destination]).each do |side|
        TABLES.each do |table, columns|
          rows = inventory.fetch(side).fetch(table).select { |r| r.fetch("id").to_i.positive? }
          rows.reject! { |r| @retained.reused?(table, r["id"]) } if @retained
          unless rows.size ==
                   @db.get_first_value(
                     "SELECT count(*) FROM receipts WHERE side=? AND kind=?",
                     [side, table],
                   )
            raise Error, "#{side} #{table} inventory changed; rerun prepare-uploads"
          end
          rows.each do |r|
            input =
              @db.get_first_value(
                "SELECT input FROM receipts WHERE side=? AND kind=? AND id=?",
                [side, table, r.fetch("id")],
              )
            unless input && JSON.parse(input) == r.values_at(*columns)
              raise Error, "#{side} #{table} #{r.fetch("id")} changed; rerun prepare-uploads"
            end
          end
        end
      end
      return target if @retained
      destinations = inventory.fetch("destination").fetch("uploads").index_by { |row| row["sha1"] }
      inventory
        .fetch("source")
        .fetch("uploads")
        .each do |incoming|
          existing = destinations[incoming["sha1"]]
          next unless incoming["id"].to_i.positive? && existing && existing["id"].to_i.positive?
          unless receipt("source", "uploads", incoming["id"]).fetch("sha256") ==
                   receipt("destination", "uploads", existing["id"]).fetch("sha256")
            raise Error, "Reused upload bytes differ: #{incoming["id"]}"
          end
        end
      target
    end

    def target
      identity.last
    end

    def identity
      JSON.parse(@db.get_first_value("SELECT value FROM metadata WHERE name='target'"))
    end

    def each_receipt(side)
      @db.execute(
        "SELECT kind,id,input,result FROM receipts WHERE side=? ORDER BY kind,id",
        [side],
      ) do |kind, id, input, result|
        yield kind, id, TABLES.fetch(kind).zip(JSON.parse(input)).to_h, JSON.parse(result)
      end
    end

    private

    def each_input_batch(configuration, inventory, target)
      if @retained
        TABLES.each do |table, columns|
          rows =
            @retained
              .source
              .fetch(table)
              .select { |row| Integer(row["id"]).positive? && !@retained.reused?(table, row["id"]) }
          rows.each_slice(1000) do |batch|
            yield(
              "source",
              table,
              columns,
              batch,
              configuration.data["source_upload_root"],
              target.dig("read_prefixes", "source")
            )
          end
        end
      else
        %w[destination source].each do |side|
          failures = 0
          inventory.connect(side) do |pg|
            pg.exec("BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY")
            TABLES.each do |table, columns|
              sql = "SELECT #{columns.join(",")} FROM #{table} WHERE id > 0 ORDER BY id"
              SourceRows.each_batch(pg, sql) do |rows|
                failures =
                  yield(
                    side,
                    table,
                    columns,
                    rows,
                    configuration.data["#{side}_upload_root"],
                    target.dig("read_prefixes", side)
                  )
              end
            end
          end
          if failures.positive?
            raise Error, "#{failures} unverified #{side} uploads; rerun prepare-uploads"
          end
        end
      end
    end

    def verify_retained_inputs!(configuration, approvals)
      source_ids = @retained.source.fetch("uploads").map { |row| Integer(row.fetch("id")) }
      unless (approvals.source_ids - source_ids).empty?
        raise Error, "Approved source IDs missing from this snapshot"
      end
      root = configuration.data["source_upload_root"]
      TABLES.each_key do |table|
        @retained
          .source
          .fetch(table)
          .each do |row|
            id = Integer(row.fetch("id"))
            next unless id.positive?
            relative = relative_path(row.fetch("url"), table)
            expected = row["original_sha1"].presence || row.fetch("sha1")
            size = row["filesize"]&.to_i
            approved = nil
            if table == "uploads"
              approved = approvals.digest_for("source", id, relative, expected, size)
              dest = @retained.reuse.fetch(table)[id]
              if dest && (approved || approvals.approved?("destination", dest))
                raise Error, "Approved hash discrepancy collides with retained upload #{id}"
              end
            end
            file = Artifacts.upload_path(root, relative, existing: false) if root
            next unless file&.file?
            digest = approved ? Digest::SHA256 : Digest::SHA1
            size_matches = size.nil? || file.size == size
            next if size_matches && digest.file(file).hexdigest == (approved || expected)
            raise Error,
                  "Source #{table} #{id} differs from recorded digest or size; run inspect-uploads --side source --id #{id}"
          end
      end
    end

    def retained_parent(id)
      row = @retained&.parent(id)
      return unless row
      relative =
        if Integer(id).negative? && row.fetch("url").match?(%r{\A/images/[\w.-]+\z})
          row.fetch("url").delete_prefix("/")
        else
          relative_path(row.fetch("url"), "uploads")
        end
      {
        "retained" => true,
        "secure" => false,
        "relative" => relative,
        "sha1" => (row["original_sha1"].presence || row.fetch("sha1")).delete_prefix("_"),
      }
    end

    def check_hosted_key!(url, table, target)
      uri = URI.parse(url)
      bucket = uri.host.to_s[/\A(.+)\.s3(?:[.-][a-z0-9.-]+)?\.amazonaws\.com(?:\.cn)?\z/i, 1]
      return unless bucket
      key = [target["prefix"].presence, relative_path(url, table)].compact.join("/")
      unless bucket == target.fetch("bucket") && uri.path == "/#{key}"
        raise Error,
              "Hosted destination URL differs from the configured bucket or tenant. Check the target or supply its read prefix."
      end
    end

    def transfer(
      store,
      root,
      read_prefix,
      table,
      row,
      parent,
      previous,
      side,
      approvals,
      check_only
    )
      relative = relative_path(row.fetch("url"), table)
      secure = parent ? parent.fetch("secure") : row["secure"] == "t"
      expected = row["original_sha1"].presence || row.fetch("sha1")
      expected_size = row["filesize"]&.to_i
      approved =
        approvals.digest_for(side, row.fetch("id"), relative, expected, expected_size) if table ==
        "uploads"
      params = store.object(relative)
      info = store.head(params)
      old = previous if previous && previous["input"] == row.values_at(*TABLES.fetch(table)) &&
        (!parent || previous["parent_digest"] == (parent["sha256"] || parent["sha1"]))
      generated = false
      status = "reused"
      if !approved && info && old && old["etag"] == info.etag.delete('"') &&
           old["size"] == info.content_length
        sha1, sha256, generated = old.values_at("sha1", "sha256", "generated")
      elsif info
        sha1, sha256 = store.digests(params)
      end
      recorded = ->(actual_sha1, actual_sha256, size) do
        (approved ? actual_sha256 == approved : actual_sha1 == expected) &&
          (!expected_size || size == expected_size)
      end
      verified = info && (generated || recorded.call(sha1, sha256, info.content_length))
      checked_size = nil
      unless verified
        with_file(store, root, read_prefix, secure, relative, parent, row) do |file, regenerated|
          file_sha1, file_sha256 = file_digests(file)
          if !regenerated && !recorded.call(file_sha1, file_sha256, file.size)
            raise Error,
                  "Supplied file differs from recorded digest or size: #{relative}; run inspect-uploads --side #{side} --id #{row.fetch("id")}"
          end
          if info
            # A previous process can have written a regenerated thumbnail just before
            # its SQLite transaction committed. Reconstruct and compare it on a retry.
            unless sha256 == file_sha256 && info.content_length == file.size
              raise Error, "Conflicting bytes at #{relative}"
            end
          elsif check_only
            status = "missing"
          else
            created =
              store.create(
                params,
                file,
                row["original_filename"] || File.basename(relative),
                secure,
                file_sha256,
              )
            info = store.head(params, known_present: true)
            unless info && info.content_length == file.size
              raise Error, "Upload missing after transfer"
            end
            if !created || created.etag != info.etag
              unless store.digests(params).last == file_sha256
                raise Error, "Conflicting bytes at #{relative}"
              end
            end
            status = regenerated ? "regenerated" : "uploaded"
          end
          checked_size = file.size
          sha1, sha256, generated = file_sha1, file_sha256, regenerated
        end
      end
      store.check_access!(params, secure) if info
      [
        {
          "relative" => relative,
          "url" => store.location(relative),
          "secure" => secure,
          "etag" => info&.etag&.delete('"'),
          "size" => info&.content_length || checked_size,
          "sha1" => sha1,
          "sha256" => sha256,
          "generated" => generated,
          "parent_digest" => parent && (parent["sha256"] || parent["sha1"]),
        },
        status,
      ]
    end

    def with_file(store, root, read_prefix, secure, relative, parent, row)
      file = Artifacts.upload_path(root, relative, existing: false) if root
      return yield(file, false) if file&.file?
      if read_prefix
        staged = Tempfile.new(["merge-backup", File.extname(relative)], binmode: true)
        if store.read_backup(read_prefix, relative, secure) { |chunk| staged.write(chunk) }
          staged.flush
          return yield(Pathname.new(staged.path), false)
        end
      end
      raise Error, "Supply #{relative} under this site's upload root" unless parent

      original = Artifacts.upload_path(root, parent.fetch("relative"), existing: false) if root
      unless original&.file?
        if parent["retained"]
          raise Error,
                "Supply the source original #{parent.fetch("relative")} to regenerate #{relative}"
        end
        downloaded =
          Tempfile.new(["merge-original", File.extname(parent.fetch("relative"))], binmode: true)
        store.read(store.object(parent.fetch("relative"))) { |chunk| downloaded.write(chunk) }
        downloaded.flush
        original = Pathname.new(downloaded.path)
      end
      expected_digest = parent["sha256"] || parent.fetch("sha1")
      digest = parent["sha256"] ? Digest::SHA256 : Digest::SHA1
      unless digest.file(original).hexdigest == expected_digest
        raise Error, "Original bytes changed"
      end
      Tempfile.create(["merge-thumbnail", File.extname(relative)]) do |tmp|
        if File.extname(relative) == ".svg"
          unless original.extname == ".svg"
            raise Error, "Cannot regenerate an SVG from a raster original"
          end
          FileUtils.cp(original, tmp.path)
        else
          resized = @thumbnail_slots.acquire { resize_thumbnail(original, tmp.path, row) }
          raise Error, "Thumbnail regeneration failed" unless resized
        end
        raise Error, "Regenerated thumbnail is empty" if tmp.size.zero?
        yield Pathname.new(tmp.path), true
      end
    ensure
      staged&.close!
      downloaded&.close!
    end

    def resize_thumbnail(original, output, row)
      attempts ||= 0
      attempts += 1
      # Discourse uses the output extension for both codecs unless a format is supplied.
      options = { format: File.extname(output).delete_prefix("."), raise_on_error: true }
      width, height = Integer(row.fetch("width")), Integer(row.fetch("height"))
      OptimizedImage.resize(original.to_s, output, width, height, **options)
    rescue StandardError => error
      # The Vips client resets a disconnected worker. Retry the local resize only.
      if attempts == 1 && defined?(DiscourseVips::WorkerUnavailable) &&
           error.is_a?(DiscourseVips::WorkerUnavailable)
        retry
      end
      # Discourse's ImageMagick decoder can read some archival JPEGs rejected by jpegli.
      unless defined?(DiscourseVips::InvalidImage) && error.is_a?(DiscourseVips::InvalidImage) &&
               %w[.jpg .jpeg].include?(original.extname.downcase)
        raise
      end
      OptimizedImage.optimize(
        :optimized_image_resize,
        original.to_s,
        output,
        "#{width}x#{height}",
        options,
      )
    end
  end
end
