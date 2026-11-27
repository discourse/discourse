# frozen_string_literal: true

module BulkImport::DiscourseMerge
  module LocalUploadFiles
    def relative_path(url, table)
      uri = URI.parse(url)
      type = table == "uploads" ? "original" : "optimized"
      relative = uri.path[%r{(?:\A|/)(#{type}/\d+X/(?:[a-f\d]/)*[\w-][\w.-]*)\z}, 1]
      raise Error, "Unsupported #{type} storage path #{uri.path.inspect}" unless relative
      relative
    end

    def file_digests(file)
      sha1 = Digest::SHA1.new
      sha256 = Digest::SHA256.new
      File.open(file, "rb") do |input|
        while (chunk = input.read(1024 * 1024))
          sha1 << chunk
          sha256 << chunk
        end
      end
      [sha1.hexdigest, sha256.hexdigest]
    end
  end

  class UploadDiagnostics
    include LocalUploadFiles

    def initialize(configuration, inventory = Inventory.new(configuration))
      @configuration = configuration
      @inventory = inventory
    end

    def each(side, id = nil)
      root =
        @configuration
          .data
          .fetch("#{side}_upload_root") do
            raise Error, "No local #{side} upload directory configured"
          end
      found = false
      @inventory.connect(side) do |pg|
        pg.exec("BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY")
        PreparedUploads::TABLES.each do |table, columns|
          condition = id ? "id = #{Integer(id)}" : "id > 0"
          SourceRows.each(
            pg,
            "SELECT #{columns.join(",")} FROM #{table} WHERE #{condition} ORDER BY id",
          ) do |row|
            found = true
            key = relative_path(row.fetch("url"), table)
            path = Artifacts.upload_path(root, key, existing: false)
            expected = row["original_sha1"].presence || row.fetch("sha1")
            size = row["filesize"]&.to_i
            evidence = {
              side: side,
              table: table,
              id: Integer(row.fetch("id")),
              relative_key: key,
              recorded_size: size,
              recorded_sha1: expected,
            }
            issues = []
            if path.file?
              sha1, sha256 = file_digests(path)
              evidence.merge!(actual_size: path.size, actual_sha1: sha1, sha256: sha256)
              issues << "size" if size && size != evidence[:actual_size]
              issues << "digest" if expected != sha1
            else
              issues << "absent locally"
            end
            yield evidence.merge(issues: issues) if id || issues.any?
          end
        end
      end
      raise Error, "Unknown #{side} media ID #{id}" if id && !found
    end

    def approve(side, id, reviewed_sha256, input: $stdin, output: $stdout)
      directory = @configuration.directory
      File.open(directory.join("workflow.lock"), "a", 0o600) do |lock|
        unless lock.flock(File::LOCK_EX | File::LOCK_NB)
          raise Error, "Another workflow command is active"
        end
        raise Error, "Use a fresh project after apply" if directory.join("active-run.json").exist?
        entry = nil
        each(side, id) { |row| entry = row if row[:table] == "uploads" }
        unless entry && entry[:recorded_size] && entry[:issues] == ["digest"] &&
                 entry[:sha256] == reviewed_sha256
          raise Error,
                "Approval requires a reviewed original of the recorded size and matching actual SHA-256"
        end
        if @configuration.preserve_destination_uploads? && side == "destination"
          raise Error, "Retained destination files are outside the transfer"
        end
        other = side == "source" ? "destination" : "source"
        @inventory.connect(side) do |pg|
          sha1 = pg.exec_params("SELECT sha1 FROM uploads WHERE id=$1", [id]).first.fetch("sha1")
          @inventory.connect(other) do |db|
            if db
                 .exec_params("SELECT 1 FROM uploads WHERE id > 0 AND sha1=$1 LIMIT 1", [sha1])
                 .ntuples
                 .positive?
              raise Error,
                    "Upload shares its recorded identity with the other forum; resolve the collision first"
            end
          end
        end
        locations = @configuration.data.fetch("preupload_locations")
        target = locations.fetch("write").delete_suffix("/")
        reads =
          locations.fetch("read_prefixes", {}).transform_values { |value| value.delete_suffix("/") }
        bucket, folder = target.delete_prefix("s3://").split("/", 2)
        approved_target = { "bucket" => bucket, "prefix" => folder.to_s, "read_prefixes" => reads }
        approved_target = @configuration.data.fetch("reviewed_upload_target", approved_target)
        @configuration.check_preupload_locations!(approved_target)
        path = directory.join(PreparedUploads::ApprovedOriginals::FILE)
        manifest = {
          "status" => "approved",
          "review_target" => "s3://#{bucket}/#{folder}",
          "destination_read_prefix" => reads["destination"],
          "entries" => [],
        }
        if path.exist?
          PreparedUploads::ApprovedOriginals.new(directory, approved_target)
          manifest = JSON.parse(path.read)
        end
        output.puts JSON.pretty_generate(entry),
                    "Write target #{target}; retained prefix #{reads["destination"] || "(none)"}"
        output.print "Approve these exact bytes? [y/N] "
        output.flush
        raise Error, "Approval cancelled" unless input.gets.to_s.strip.downcase == "y"
        entries = manifest.fetch("entries")
        entries.reject! { |old| old["side"] == side && old["id"] == id }
        entries << entry.slice(:side, :id, :relative_key, :recorded_sha1, :sha256).merge(
          size: entry.fetch(:actual_size),
        )
        Configuration.write(path, manifest)
      end
    end
  end
end
